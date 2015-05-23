//
// Image downloader for iOS/Swift.
//
// https://github.com/evgenyneu/moa
//
// This file was automatically generated by combining multiple Swift source files.
//


// ----------------------------
//
// Moa.swift
//
// ----------------------------

import UIKit

/**
Downloads an image by url.

Setting `moa.url` property of `UIImageView` instance starts asynchronous image download using NSURLSession class.
When download is completed the image is automatically shows in the image view.

  let imageView = UIImageView()
  imageView.moa.url = "http://site.com/image.jpg"


The class can be instantiated and used without `UIImageView`:

  let moa = Moa()
  moa.onSuccessAsync = { image in
    return image
  }
  moa.url = "http://site.com/image.jpg"

*/
public final class Moa {
  private var imageDownloader: MoaImageDownloader?
  private weak var imageView: UIImageView?

  /**
  
  Instantiate Moa when used without UIImageView.
  
    let moa = Moa()
    moa.onSuccessAsync = { image in }
    moa.url = "http://site.com/image.jpg"
  
  */
  public init() { }
  
  init(imageView: UIImageView) {
    self.imageView = imageView
  }

  /**

  Assign an image URL to start the download.
  When download is completed the image is automatically shows in the image view.
  
    imageView.moa.url = "http://mysite.com/image.jpg"
  
  Supply `onSuccessAsync` closure to receive an image when used without UIImageView:
  
    moa.onSuccessAsync = { image in
      return image
    }

  */
  public var url: String? {
    didSet {
      cancel()
      
      if let url = url {
        startDownload(url)
      }
    }
  }
  
  /**
  
  Cancels image download.
  
  Ongoing image download for the UIImageView is *automatically* cancelled when:
  
  1. Image view is deallocated.
  2. New image download is started: `imageView.moa.url = ...`.
  
  Call this method to manually cancel the download.
  
    imageView.moa.cancel()

  */
  public func cancel() {
    imageDownloader?.cancel()
    imageDownloader = nil
  }
  
  /**

  The closure will be called *asynchronously* after download finishes and before the image
  is assigned to the image view.
  
  This is a good place to manipulate the image before it is shown.
  
  The closure returns an image that will be shown in the image view.
  Return nil if you do not want the image to be shown.
  
    moa.onSuccessAsync = { image in
      // Manipulate the image
      return image
    }

  */
  public var onSuccessAsync: ((UIImage)->(UIImage?))?
  
  
  /**
  
  The closure is called *asynchronously* if image download fails.
  [See Wiki](https://github.com/evgenyneu/moa/wiki/Moa-errors) for the list of possible error codes.
  
    onErrorAsync = { error, httpUrlResponse in
      // Report error
    }
  
  */
  public var onErrorAsync: ((NSError, NSHTTPURLResponse?)->())?
  
  private func startDownload(url: String) {
    cancel()
    imageDownloader = MoaImageDownloader()
    
    imageDownloader?.startDownload(url,
      onSuccess: { [weak self] image in
        self?.onHandleSuccess(image)
      },
      onError: { [weak self] error, response in
        self?.onErrorAsync?(error, response)
      }
    )
  }
  
  private func onHandleSuccess(image: UIImage) {
    var imageForView: UIImage? = image
    
    if let onSuccessAsync = onSuccessAsync {
      imageForView = onSuccessAsync(image)
    }
    
    if let imageView = imageView {
      dispatch_async(dispatch_get_main_queue()) {
        imageView.image = imageForView
      }
    }
  }
}


// ----------------------------
//
// MoaHttp.swift
//
// ----------------------------

import UIKit

/**

Shortcut function for creating NSURLSessionDataTask.

*/
struct MoaHttp {
  static func createDataTask(url: String,
    onSuccess: (NSData, NSHTTPURLResponse)->(),
    onError: (NSError, NSHTTPURLResponse?)->()) -> NSURLSessionDataTask? {
      
    if let nsUrl = NSURL(string: url) {
      return createDataTask(nsUrl, onSuccess: onSuccess, onError: onError)
    }
    
    // Error converting string to NSURL
    onError(MoaHttpErrors.InvalidUrlString.new, nil)
    return nil
  }
  
  private static func createDataTask(nsUrl: NSURL,
    onSuccess: (NSData, NSHTTPURLResponse)->(),
    onError: (NSError, NSHTTPURLResponse?)->()) -> NSURLSessionDataTask? {
      
    return NSURLSession.sharedSession().dataTaskWithURL(nsUrl) { (data, response, error) in
      if let httpResponse = response as? NSHTTPURLResponse {
        if error == nil {
          onSuccess(data, httpResponse)
        } else {
          onError(error, httpResponse)
        }
      } else {
        onError(error, nil)
      }
    }
  }
}


// ----------------------------
//
// MoaHttpErrors.swift
//
// ----------------------------

import Foundation

/**

Http error types.

*/
public enum MoaHttpErrors: Int {
  /// Incorrect URL is supplied.
  case InvalidUrlString = -1
  
  internal var new: NSError {
    return NSError(domain: "MoaHttpErrorDomain", code: rawValue, userInfo: nil)
  }
}


// ----------------------------
//
// MoaHttpImage.swift
//
// ----------------------------

//
// Helper functions for downloading an image and processing the response.
//

import UIKit

struct MoaHttpImage {
  static func createDataTask(url: String,
    onSuccess: (UIImage)->(),
    onError: (NSError, NSHTTPURLResponse?)->()) -> NSURLSessionDataTask? {
    
    return MoaHttp.createDataTask(url,
      onSuccess: { data, response in
        self.handleSuccess(data, response: response, onSuccess: onSuccess, onError: onError)
      },
      onError: onError
    )
  }
  
  static func handleSuccess(data: NSData,
    response: NSHTTPURLResponse,
    onSuccess: (UIImage)->(),
    onError: (NSError, NSHTTPURLResponse?)->()) {
      
    // Show error if response code is not 200
    if response.statusCode != 200 {
      onError(MoaHttpImageErrors.HttpStatusCodeIsNot200.new, response)
      return
    }
    
    // Ensure response has the valid MIME type
    if let mimeType = response.MIMEType {
      if !validMimeType(mimeType) {
        // Not an image Content-Type http header
        let error = MoaHttpImageErrors.NotAnImageContentTypeInResponseHttpHeader.new
        onError(error, response)
        return
      }
    } else {
      // Missing Content-Type http header
      let error = MoaHttpImageErrors.MissingResponseContentTypeHttpHeader.new
      onError(error, response)
      return
    }
      
    if let image = UIImage(data: data) {
      onSuccess(image)
    } else {
      // Failed to convert response data to UIImage
      let error = MoaHttpImageErrors.FailedToReadImageData.new
      onError(error, response)
    }
  }
  
  private static func validMimeType(mimeType: String) -> Bool {
    let validMimeTypes = ["image/jpeg", "image/pjpeg", "image/png"]
    return contains(validMimeTypes, mimeType)
  }
}


// ----------------------------
//
// MoaHttpImageErrors.swift
//
// ----------------------------

import Foundation

/**

Image download error types.

*/
public enum MoaHttpImageErrors: Int {
  /// Response HTTP status code is not 200.
  case HttpStatusCodeIsNot200 = -1
  
  /// Response is missing Content-Type http header.
  case MissingResponseContentTypeHttpHeader = -2
  
  /// Response Content-Type http header is not an image type.
  case NotAnImageContentTypeInResponseHttpHeader = -3
  
  /// Failed to convert response data to UIImage.
  case FailedToReadImageData = -4

  internal var new: NSError {
    return NSError(domain: "MoaHttpImageErrorDomain", code: rawValue, userInfo: nil)
  }
}


// ----------------------------
//
// MoaImageDownloader.swift
//
// ----------------------------

import UIKit

final class MoaImageDownloader {
  var task: NSURLSessionDataTask?
  var cancelled = false
  
  deinit {
    cancel()
  }
  
  func startDownload(url: String, onSuccess: (UIImage)->(),
    onError: (NSError, NSHTTPURLResponse?)->()) {
    
    cancelled = false
  
    task = MoaHttpImage.createDataTask(url,
      onSuccess: onSuccess,
      onError: { [weak self] error, response in
        if let currentSelf = self
          where !currentSelf.cancelled { // Do not report error if task was manually cancelled
    
          onError(error, response)
        }
      }
    )
      
    task?.resume()
  }
  
  func cancel() {
    task?.cancel()
    cancelled = true
  }
}


// ----------------------------
//
// UIImageView+moa.swift
//
// ----------------------------

import UIKit

private var xoAssociationKey: UInt8 = 0

/**

UIImageView extension for downloading image.

  let imageView = UIImageView()
  imageView.moa.url = "http://site.com/image.jpg"

*/
public extension UIImageView {
  /**
  
  Image download extension.
  Assign its `url` property to download and show the image in the `UIImageView`.
  
    let imageView = UIImageView()
    imageView.moa.url = "http://site.com/image.jpg"
  
  */
  public var moa: Moa {
    get {
      if let value = objc_getAssociatedObject(self, &xoAssociationKey) as? Moa {
        return value
      } else {
        let moa = Moa(imageView: self)
        objc_setAssociatedObject(self, &xoAssociationKey, moa, objc_AssociationPolicy(OBJC_ASSOCIATION_RETAIN))
        return moa
      }
    }
    
    set {
      objc_setAssociatedObject(self, &xoAssociationKey, newValue, objc_AssociationPolicy(OBJC_ASSOCIATION_RETAIN))
    }
  }
}


