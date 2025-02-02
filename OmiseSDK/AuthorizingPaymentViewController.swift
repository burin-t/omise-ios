import Foundation
import WebKit
import os

/// Delegate to receive authorizing payment events.
@objc(OMSAuthorizingPaymentViewControllerDelegate)
@available(iOSApplicationExtension, unavailable)
// swiftlint:disable:next attributes
public protocol AuthorizingPaymentViewControllerDelegate: AnyObject {
    /// A delegation method called when the authorizing payment process is completed.
    /// - parameter viewController: The authorizing payment controller that call this method.
    /// - parameter redirectedURL: A URL returned from the authorizing payment process.
    func authorizingPaymentViewController(_ viewController: AuthorizingPaymentViewController, didCompleteAuthorizingPaymentWithRedirectedURL redirectedURL: URL)
    
    /// A delegation method called when user cancel the authorizing payment process.
    func authorizingPaymentViewControllerDidCancel(_ viewController: AuthorizingPaymentViewController)
    
    @available(*, unavailable,
    renamed: "authorizingPaymentViewController(_:didCompleteAuthorizingPaymentWithRedirectedURL:)")
    func omiseAuthorizingPaymentViewController(_ viewController: AuthorizingPaymentViewController, didCompleteAuthorizingPaymentWithRedirectedURL redirectedURL: URL)
    
    @available(*, unavailable,
    renamed: "authorizingPaymentViewControllerDidCancel(_:)")
    func omiseAuthorizingPaymentViewControllerDidCancel(_ viewController: AuthorizingPaymentViewController)
}

@available(*, deprecated, renamed: "AuthorizingPaymentViewController")
@available(iOSApplicationExtension, unavailable)
public typealias Omise3DSViewController = AuthorizingPaymentViewController

@available(iOSApplicationExtension, unavailable)
@available(*, deprecated, renamed: "AuthorizingPaymentViewControllerDelegate")
public typealias Omise3DSViewControllerDelegate = AuthorizingPaymentViewControllerDelegate

@available(*, deprecated, renamed: "AuthorizingPaymentViewController")
@available(iOSApplicationExtension, unavailable)
public typealias OmiseAuthorizingPaymentViewController = AuthorizingPaymentViewController

@available(*, deprecated, renamed: "AuthorizingPaymentViewControllerDelegate")
@available(iOSApplicationExtension, unavailable)
// swiftlint:disable:next type_name
public typealias OmiseAuthorizingPaymentViewControllerDelegate = AuthorizingPaymentViewControllerDelegate

/*:
 Drop-in authorizing payment handler view controller that automatically display the authorizing payment verification form
 which supports `3DS`, `Internet Banking` and other offsite payment methods those need to be authorized via a web browser.
 
 - remark:
   This is still an experimental API. If you encountered with any problem with this API, please feel free to report to Omise.
 */
@objc(OMSAuthorizingPaymentViewController)
@available(iOSApplicationExtension, unavailable)
// swiftlint:disable:next attributes
public class AuthorizingPaymentViewController: UIViewController {
    /// Authorized URL given from Omise in the created `Charge` object.
    public var authorizedURL: URL? {
        didSet {
            guard isViewLoaded else {
                return
            }
            
            startAuthorizingPaymentProcess()
        }
    }
    
    /// The expected return URL patterns described in the URLComponents object.
    ///
    /// The rule is the scheme and host must be matched and must have the path as a prefix.
    /// Example: if the return URL is `https://www.example.com/products/12345` the expected return URL should have a URLComponents with scheme of `https`, host of `www.example.com` and the path of `/products/`
    public var expectedReturnURLPatterns: [URLComponents] = []
    
    /// A delegate object that will recieved the authorizing payment events.
    public weak var delegate: AuthorizingPaymentViewControllerDelegate?
    
    let webView = WKWebView(frame: CGRect.zero, configuration: WKWebViewConfiguration())
    let okButtonTitle = NSLocalizedString("OK", comment: "OK button for JavaScript panel")
    let confirmButtonTitle = NSLocalizedString("Confirm", comment: "Confirm button for JavaScript panel")
    let cancelButtonTitle = NSLocalizedString("Cancel", comment: "Cancel button for JavaScript panel")
    
    /// A factory method for creating a authorizing payment view controller comes in UINavigationController stack.
    ///
    /// - parameter authorizedURL: The authorized URL given in `Charge` object that will be set to `OmiseAuthorizingPaymentViewController`
    /// - parameter expectedReturnURLPatterns: The expected return URL patterns.
    /// - parameter delegate: A delegate object that will recieved authorizing payment events.
    ///
    /// - returns: A UINavigationController with `OmiseAuthorizingPaymentViewController` as its root view controller
    @objc(authorizingPaymentViewControllerNavigationWithAuthorizedURL:expectedReturnURLPatterns:delegate:)
    // swiftlint:disable:next attributes
    public static func makeAuthorizingPaymentViewControllerNavigationWithAuthorizedURL(_ authorizedURL: URL, expectedReturnURLPatterns: [URLComponents], delegate: AuthorizingPaymentViewControllerDelegate) -> UINavigationController {
        let storyboard = UIStoryboard(name: "OmiseSDK", bundle: .omiseSDK)
        let navigationController = storyboard.instantiateViewController(
            withIdentifier: "DefaultAuthorizingPaymentViewControllerWithNavigation"
        ) as! UINavigationController // swiftlint:disable:this force_cast

        // swiftlint:disable:next force_cast
        let viewController = navigationController.topViewController as! AuthorizingPaymentViewController
        viewController.authorizedURL = authorizedURL
        viewController.expectedReturnURLPatterns = expectedReturnURLPatterns
        viewController.delegate = delegate
        
        return navigationController
    }
    
    @available(*, deprecated,
    message: "Please use the new method that confrom to Objective-C convention +[AuthorizingPaymentViewController authorizingPaymentViewControllerNavigationWithAuthorizedURL:expectedReturnURLPatterns:delegate:] as of this method will be removed in the future release.", // swiftlint:disable:this line_length
    renamed: "makeAuthorizingPaymentViewControllerNavigationWithAuthorizedURL(_:expectedReturnURLPatterns:delegate:)")
    @objc(makeAuthorizingPaymentViewControllerNavigationWithAuthorizedURL:expectedReturnURLPatterns:delegate:)
    // swiftlint:disable:next identifier_name attributes
    public static func __makeAuthorizingPaymentViewControllerNavigationWithAuthorizedURL(_ authorizedURL: URL, expectedReturnURLPatterns: [URLComponents], delegate: AuthorizingPaymentViewControllerDelegate) -> UINavigationController {
        return AuthorizingPaymentViewController.makeAuthorizingPaymentViewControllerNavigationWithAuthorizedURL(
            authorizedURL,
            expectedReturnURLPatterns: expectedReturnURLPatterns,
            delegate: delegate
        )
    }
    
    /// A factory method for creating a authorizing payment view controller comes in UINavigationController stack.
    ///
    /// - parameter authorizedURL: The authorized URL given in `Charge` object that will be set to `OmiseAuthorizingPaymentViewController`
    /// - parameter expectedReturnURLPatterns: The expected return URL patterns.
    /// - parameter delegate: A delegate object that will recieved authorizing payment events.
    ///
    /// - returns: An `OmiseAuthorizingPaymentViewController` with given authorized URL and delegate.
    @objc(authorizingPaymentViewControllerWithAuthorizedURL:expectedReturnURLPatterns:delegate:)
    // swiftlint:disable:next attributes
    public static func makeAuthorizingPaymentViewControllerWithAuthorizedURL(_ authorizedURL: URL, expectedReturnURLPatterns: [URLComponents], delegate: AuthorizingPaymentViewControllerDelegate) -> AuthorizingPaymentViewController {
        let storyboard = UIStoryboard(name: "OmiseSDK", bundle: .omiseSDK)
        let viewController = storyboard.instantiateViewController(
            withIdentifier: "DefaultAuthorizingPaymentViewController"
        ) as! AuthorizingPaymentViewController // swiftlint:disable:this force_cast
        viewController.authorizedURL = authorizedURL
        viewController.expectedReturnURLPatterns = expectedReturnURLPatterns
        viewController.delegate = delegate
        
        return viewController
    }
    
    @available(*, deprecated,
    message: "Please use the new method that confrom to Objective-C convention +[AuthorizingPaymentViewController authorizingPaymentViewControllernWithAuthorizedURL:expectedReturnURLPatterns:delegate:] as of this method will be removed in the future release.",  // swiftlint:disable:this line_length
    renamed: "makeAuthorizingPaymentViewControllerWithAuthorizedURL(_:expectedReturnURLPatterns:delegate:)")
    @objc(makeAuthorizingPaymentViewControllerWithAuthorizedURL:expectedReturnURLPatterns:delegate:)
    // swiftlint:disable:next identifier_name attributes
    public static func __makeAuthorizingPaymentViewControllerWithAuthorizedURL(_ authorizedURL: URL, expectedReturnURLPatterns: [URLComponents], delegate: AuthorizingPaymentViewControllerDelegate) -> AuthorizingPaymentViewController {
        return AuthorizingPaymentViewController.makeAuthorizingPaymentViewControllerWithAuthorizedURL(
            authorizedURL,
            expectedReturnURLPatterns: expectedReturnURLPatterns,
            delegate: delegate
        )
    }
    
    // need to refactor loadView, removing super results in crash
    // swiftlint:disable:next prohibited_super_call
    public override func loadView() {
        super.loadView()
        
        webView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(webView)
        
        webView.topAnchor.constraint(equalTo: topLayoutGuide.bottomAnchor).isActive = true
        webView.bottomAnchor.constraint(equalTo: bottomLayoutGuide.topAnchor).isActive = true
        webView.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
        webView.trailingAnchor.constraint(equalTo: view.trailingAnchor).isActive = true
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        webView.navigationDelegate = self
        webView.uiDelegate = self
    }
    
    public override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        startAuthorizingPaymentProcess()
    }
    
    @IBAction private func cancelAuthorizingPaymentProcess(_ sender: UIBarButtonItem) {
        os_log("Authorization process was cancelled, trying to notify the delegate", log: uiLogObject, type: .info)
        delegate?.authorizingPaymentViewControllerDidCancel(self)
        if delegate == nil {
            os_log("Authorization process was cancelled but no delegate to be notified", log: uiLogObject, type: .default)
        }
    }
    
    private func startAuthorizingPaymentProcess() {
        guard let authorizedURL = authorizedURL, !expectedReturnURLPatterns.isEmpty else {
            assertionFailure("Insufficient authorizing payment information")
            os_log("Refusing to initialize sdk client with a non-public key: %{private}@", log: uiLogObject, type: .error)
            return
        }
        
        os_log("Starting the authorizing process with %{private}@ URL", log: uiLogObject, type: .info, authorizedURL.absoluteString)
        let request = URLRequest(url: authorizedURL, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: 60.0)
        webView.load(request)
    }
    
    private func verifyPaymentURL(_ url: URL) -> Bool {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true) else {
            return false
        }
        
        return expectedReturnURLPatterns.contains { expectedURLComponents -> Bool in
            return expectedURLComponents.scheme == components.scheme
                && expectedURLComponents.host == components.host
                && components.path.hasPrefix(expectedURLComponents.path)
        }
    }
    
}

@available(iOSApplicationExtension, unavailable)
extension AuthorizingPaymentViewController: WKNavigationDelegate {
    public func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Swift.Void) {
        if let url = navigationAction.request.url, verifyPaymentURL(url) {
            os_log("Redirected to expected %{private}@ URL, trying to notify the delegate",
                   log: uiLogObject,
                   type: .info,
                   url.absoluteString)
            decisionHandler(.cancel)
            delegate?.authorizingPaymentViewController(self, didCompleteAuthorizingPaymentWithRedirectedURL: url)
            if delegate == nil {
                os_log("Redirected to expected %{private}@ URL but no delegate to be notified",
                       log: uiLogObject,
                       type: .default,
                       url.absoluteString)
            }
        } else if let url = navigationAction.request.url, let scheme = url.scheme?.lowercased(), (scheme != "https" && scheme != "http") {
            os_log("Redirected to custom-scheme %{private}@ URL",
                   log: uiLogObject,
                   type: .debug,
                   navigationAction.request.url?.absoluteString ?? "<empty>")
            
            UIApplication.shared.open(url)
            decisionHandler(.cancel)
        } else {
            os_log("Redirected to non-expected %{private}@ URL",
                   log: uiLogObject,
                   type: .debug,
                   navigationAction.request.url?.absoluteString ?? "<empty>")
            decisionHandler(.allow)
        }
    }
}

@available(iOSApplicationExtension, unavailable)
extension AuthorizingPaymentViewController: WKUIDelegate {
    public func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {

        let alertController = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        let okAction = UIAlertAction(title: okButtonTitle, style: .default) { _ in
            alertController.dismiss(animated: true, completion: nil)
            completionHandler()
        }
        
        alertController.addAction(okAction)
        
        // NOTE: Must present an UIAlertController on AuthorizingPaymentViewController
        self.present(alertController, animated: true)
    }
    
    public func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
                
        let alertController = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        let confirmAction = UIAlertAction(title: confirmButtonTitle, style: .default) { _ in
            completionHandler(true)
        }
        let cancelAction = UIAlertAction(title: cancelButtonTitle, style: .cancel) { _ in
            completionHandler(false)
        }
        
        alertController.addAction(confirmAction)
        alertController.addAction(cancelAction)

        // NOTE: Must present an UIAlertController on AuthorizingPaymentViewController
        self.present(alertController, animated: true, completion: nil)
    }
    
    public func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String, defaultText: String?, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (String?) -> Void) {
        let alertController = UIAlertController(title: nil, message: prompt, preferredStyle: .alert)
        alertController.addTextField { (textField) in
            textField.text = defaultText
        }
        let okAction = UIAlertAction(title: okButtonTitle, style: .default) { _ in
            if let text = alertController.textFields?.first?.text {
                completionHandler(text)
            } else {
                completionHandler(defaultText)
            }
        }
        let cancelAction = UIAlertAction(title: cancelButtonTitle, style: .cancel) { _ in
            completionHandler(nil)
        }
        
        alertController.addAction(okAction)
        alertController.addAction(cancelAction)
        
        // NOTE: Must present an UIAlertController on AuthorizingPaymentViewController
        self.present(alertController, animated: true, completion: nil)
    }
}
