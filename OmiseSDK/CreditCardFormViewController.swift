// swiftlint:disable file_length

import UIKit
import os.log

// swiftlint:disable line_length
public protocol CreditCardFormViewControllerDelegate: AnyObject {
    /// Delegate method for receiving token data when card tokenization succeeds.
    /// - parameter token: `OmiseToken` instance created from supplied credit card data.
    /// - seealso: [Tokens API](https://www.omise.co/tokens-api)
    func creditCardFormViewController(_ controller: CreditCardFormViewController, didSucceedWithToken token: Token)

    /// Delegate method for receiving error information when card tokenization failed.
    /// This allows you to have fine-grained control over error handling when setting
    /// `handleErrors` to `false`.
    /// - parameter error: The error that occurred during tokenization.
    /// - note: This delegate method will *never* be called if `handleErrors` property is set to `true`.
    func creditCardFormViewController(_ controller: CreditCardFormViewController, didFailWithError error: Error)

    func creditCardFormViewControllerDidCancel(_ controller: CreditCardFormViewController)
}

/// Delegate to receive card tokenization events.
@available(*, deprecated, renamed: "CreditCardFormViewControllerDelegate")
public typealias CreditCardFormControllerDelegate = CreditCardFormViewControllerDelegate

@available(*, unavailable, renamed: "CreditCardFormViewControllerDelegate")
public protocol CreditCardFormDelegate: CreditCardFormViewControllerDelegate {

    @available(*, deprecated,
                renamed: "CreditCardFormViewControllerDelegate.creditCardFormViewController(_:didSucceedWithToken:)")
    func creditCardForm(_ controller: CreditCardFormController, didSucceedWithToken token: Token)

    @available(*, deprecated,
                renamed: "CreditCardFormViewControllerDelegate.creditCardFormViewController(_:didFailWithError:)")
    func creditCardForm(_ controller: CreditCardFormController, didFailWithError error: Error)
}

@available(*, deprecated,
            message: "This delegate name is deprecated. Please use the new name of `OMSCreditCardFormViewControllerDelegate`",
            renamed: "OMSCreditCardFormViewControllerDelegate")
@objc public protocol OMSCreditCardFormDelegate: OMSCreditCardFormViewControllerDelegate {}

@objc
// swiftlint:disable:next attributes
public protocol OMSCreditCardFormViewControllerDelegate: AnyObject {
    /// Delegate method for receiving token data when card tokenization succeeds.
    /// - parameter token: `OmiseToken` instance created from supplied credit card data.
    /// - seealso: [Tokens API](https://www.omise.co/tokens-api)
    @objc func creditCardFormViewController(_ controller: CreditCardFormViewController, didSucceedWithToken token: __OmiseToken)

    /// Delegate method for receiving error information when card tokenization failed.
    /// This allows you to have fine-grained control over error handling when setting
    /// `handleErrors` to `false`.
    /// - parameter error: The error that occurred during tokenization.
    /// - note: This delegate method will *never* be called if `handleErrors` property is set to `true`.
    @objc func creditCardFormViewController(_ controller: CreditCardFormViewController, didFailWithError error: NSError)

    @objc optional func creditCardFormViewControllerDidCancel(_ controller: CreditCardFormViewController)

    @available(*, unavailable,
                message: "Implement the new -[OMSCreditCardFormViewControllerDelegate creditCardFormViewController:didSucceedWithToken:] instead",
                renamed: "creditCardFormViewController(_:didSucceedWithToken:)")
    // swiftlint:disable:next attributes
    @objc func creditCardForm(_ controller: CreditCardFormViewController, didSucceedWithToken token: __OmiseToken)

    @available(*, unavailable,
                message: "Implement the new -[OMSCreditCardFormViewControllerDelegate creditCardFormViewController:didFailWithError:] instead",
                renamed: "creditCardFormViewController(_:didFailWithError:)")
    // swiftlint:disable:next attributes
    @objc func creditCardForm(_ controller: CreditCardFormViewController, didFailWithError error: NSError)
}

@available(*, deprecated, renamed: "CreditCardFormViewController")
public typealias CreditCardFormController = CreditCardFormViewController

/// Drop-in credit card input form view controller that automatically tokenizes credit
/// card information.
@objc(OMSCreditCardFormViewController)
public class CreditCardFormViewController: UIViewController, PaymentChooserUI, PaymentFormUIController {
    // swiftlint:disable:previous attributes type_body_length

    typealias ViewModel = CreditCardFormViewModel
    typealias ViewContext = CreditCardFormViewContext
    typealias Field = ViewContext.Field

    struct Style {
        var billingStackSpacing = CGFloat(12)
    }
    private var style = Style()

    private lazy var viewModel: ViewModel = {
        ViewModel()
    }()
    /// Omise public key for calling tokenization API.
    @objc public var publicKey: String?

    /// Delegate to receive CreditCardFormController result.
    public weak var delegate: CreditCardFormViewControllerDelegate?
    /// Delegate to receive CreditCardFormController result.
    @objc(delegate) public weak var __delegate: OMSCreditCardFormViewControllerDelegate? // swiftlint:disable:this identifier_name

    /// A boolean flag to enables/disables automatic error handling. Defaults to `true`.
    @objc public var handleErrors = true

    @IBInspectable public var preferredPrimaryColor: UIColor? {
        didSet {
            applyPrimaryColor()
        }
    }

    @IBInspectable public var preferredSecondaryColor: UIColor? {
        didSet {
            applySecondaryColor()
        }
    }

    @IBInspectable public var errorMessageTextColor: UIColor! = CreditCardFormViewController.defaultErrorMessageTextColor {
        didSet {
            if errorMessageTextColor == nil {
                errorMessageTextColor = CreditCardFormViewController.defaultErrorMessageTextColor
            }

            if isViewLoaded {
                errorLabels.forEach {
                    $0.textColor = errorMessageTextColor
                }
            }
        }
    }

    // swiftlint:disable:next weak_delegate
    private lazy var overlayTransitionDelegate = OverlayPanelTransitioningDelegate()

    var isInputDataValid: Bool {
        return formFields.allSatisfy { $0.isValid }
    }

    var currentEditingTextField: OmiseTextField?
    private var hasErrorMessage = false

    @IBOutlet var formFields: [OmiseTextField]!
    @IBOutlet var formLabels: [UILabel]!
    @IBOutlet var errorLabels: [UILabel]!

    @IBOutlet var contentView: UIScrollView!

    @IBOutlet private var cardNumberTextField: CardNumberTextField!
    @IBOutlet private var cardNameTextField: CardNameTextField!
    @IBOutlet private var expiryDateTextField: CardExpiryDateTextField!
    @IBOutlet private var secureCodeTextField: CardCVVTextField!

    private var countryInputView = TextFieldView(id: "country")

    @IBOutlet private var submitButton: MainActionButton!

    @IBOutlet var formFieldsAccessoryView: UIToolbar!
    @IBOutlet var gotoPreviousFieldBarButtonItem: UIBarButtonItem!
    @IBOutlet var gotoNextFieldBarButtonItem: UIBarButtonItem!
    @IBOutlet var doneEditingBarButtonItem: UIBarButtonItem!

    @IBOutlet private var creditCardNumberErrorLabel: UILabel!
    @IBOutlet private var cardHolderNameErrorLabel: UILabel!
    @IBOutlet private var cardExpiryDateErrorLabel: UILabel!
    @IBOutlet private var cardSecurityCodeErrorLabel: UILabel!

    @IBOutlet private var errorBannerView: UIView!
    @IBOutlet private var errorTitleLabel: UILabel!
    @IBOutlet private var errorMessageLabel: UILabel!
    @IBOutlet private var hidingErrorBannerConstraint: NSLayoutConstraint!
    @IBOutlet private var emptyErrorMessageConstraint: NSLayoutConstraint!
    @IBOutlet private var cardBrandIconImageView: UIImageView!
    @IBOutlet private var cvvInfoButton: UIButton!
    @IBOutlet private var billingStackView: UIStackView!

    private lazy var addressStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.distribution = .equalSpacing
        stackView.alignment = .fill
        stackView.spacing = style.billingStackSpacing
        return stackView
    }()

    @IBOutlet private var requestingIndicatorView: UIActivityIndicatorView!
    @objc public static let defaultErrorMessageTextColor = UIColor.error

    /// A boolean flag that enables/disables Card.IO integration.
    @available(*, unavailable, message: "Built in support for Card.ios was removed. You can implement it in your app and call the setCreditCardInformation(number:name:expiration:) method")
    @objc public var cardIOEnabled: Bool { return true }

    /// Factory method for creating CreditCardFormController with given public key.
    /// - parameter publicKey: Omise public key.
    @objc(creditCardFormViewControllerWithPublicKey:)
    // swiftlint:disable:next attributes
    public static func makeCreditCardFormViewController(withPublicKey publicKey: String) -> CreditCardFormViewController {
        let storyboard = UIStoryboard(name: "OmiseSDK", bundle: .omiseSDK)
        // swiftlint:disable:next force_cast
        let creditCardForm = storyboard.instantiateInitialViewController() as! CreditCardFormViewController
        creditCardForm.publicKey = publicKey

        return creditCardForm
    }

    @available(*, deprecated,
                message: "Please use the new method that confrom to Objective-C convention +[OMSCreditCardFormViewController creditCardFormViewControllerWithPublicKey:] as of this method will be removed in the future release.",
                renamed: "makeCreditCardFormViewController(withPublicKey:)")
    @objc(makeCreditCardFormWithPublicKey:) public static func __makeCreditCardForm(withPublicKey publicKey: String) -> CreditCardFormViewController { // swiftlint:disable:this identifier_name
        return CreditCardFormViewController.makeCreditCardFormViewController(withPublicKey: publicKey)
    }

    public func setCreditCardInformationWith(number: String?, name: String?, expiration: (month: Int, year: Int)?) {
        cardNumberTextField.text = number
        cardNameTextField.text = name

        if let expiration = expiration, 1...12 ~= expiration.month, expiration.year > 0 {
            expiryDateTextField.text = String(format: "%02d/%d", expiration.month, expiration.year % 100)
        }

        updateSupplementaryUI()

        os_log("The custom credit card information was set - %{private}@", log: uiLogObject, type: .debug, String((number ?? "").suffix(4)))
    }

    @objc(setCreditCardInformationWithNumber:name:expirationMonth:expirationYear:)
    // swiftlint:disable:next attributes
    public func __setCreditCardInformation(number: String, name: String, expirationMonth: Int, expirationYear: Int) { // swiftlint:disable:this identifier_name
        let month: Int?
        let year: Int?
        if Calendar.validExpirationMonthRange ~= expirationMonth {
            month = expirationMonth
        } else {
            month = nil
        }

        if expirationYear > 0 && expirationYear != NSNotFound {
            year = expirationYear
        } else {
            year = nil
        }

        let expiration: (month: Int, year: Int)?
        if let month = month, let year = year {
            expiration = (month: month, year: year)
        } else {
            expiration = nil
        }

        self.setCreditCardInformationWith(number: number, name: name, expiration: expiration)
    }
    // swiftlint:enable line_length

    // need to refactor loadView, removing super results in crash
    // swiftlint:disable:next prohibited_super_call
    public override func loadView() {
        super.loadView()

        view.backgroundColor = UIColor.background
        submitButton.defaultBackgroundColor = view.tintColor
        submitButton.disabledBackgroundColor = .line

        cvvInfoButton.tintColor = .badgeBackground
        formFieldsAccessoryView.barTintColor = .formAccessoryBarTintColor

#if compiler(>=5.1)
        if #available(iOS 13, *) {
            let appearance = navigationItem.standardAppearance ?? UINavigationBarAppearance(idiom: .phone)
            appearance.configureWithOpaqueBackground()
            appearance.titleTextAttributes = [
                NSAttributedString.Key.foregroundColor: UIColor.headings
            ]
            appearance.largeTitleTextAttributes = [
                NSAttributedString.Key.foregroundColor: UIColor.headings
            ]
            let renderer = UIGraphicsImageRenderer(size: CGSize(width: 1, height: 1))
            let image = renderer.image { (context) in
                context.cgContext.setFillColor(UIColor.line.cgColor)
                context.fill(CGRect(origin: .zero, size: CGSize(width: 1, height: 1)))
            }
            appearance.shadowImage = image.resizableImage(withCapInsets: UIEdgeInsets.zero)
                .withRenderingMode(.alwaysTemplate)
            appearance.shadowColor = preferredSecondaryColor ?? defaultPaymentChooserUISecondaryColor
            navigationItem.standardAppearance = appearance

            let scrollEdgeAppearance = appearance.copy()
            appearance.shadowColor = preferredSecondaryColor ?? defaultPaymentChooserUISecondaryColor
            navigationItem.scrollEdgeAppearance = scrollEdgeAppearance
        }
#endif
    }

    private func setupBillingStackView() {
        billingStackView.distribution = .equalSpacing
        billingStackView.alignment = .fill
        billingStackView.spacing = style.billingStackSpacing
        setupCountryField()
    }

    private func setupCountryField() {
        let input = countryInputView
        input.title = "CreditCard.field.country".localized()
        billingStackView.addArrangedSubview(input)

        input.textFieldUserInteractionEnabled = false
        input.text = viewModel.countryListViewModel.selectedCountry?.name
        input.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(onCountryInputTapped)))
    }

    @objc private func onCountryInputTapped() {
        let vc = CountryListViewController(viewModel: viewModel.countryListViewModel)
        vc.title = countryInputView.title
        vc.viewModel?.onSelectCountry = { [weak self] country in
            guard let self = self else { return }
            self.countryInputView.text = country.name

            if let nc = self.navigationController {
                nc.popToViewController(self, animated: true)
            } else {
                self.dismiss(animated: true)
            }

            self.addressStackView.isHiddenInStackView = !self.viewModel.isAddressFieldsVisible
            self.updateSubmitButtonState()

        }

        if let nc = navigationController {
            nc.pushViewController(vc, animated: true)
        } else {
            present(vc, animated: true)
        }
    }

    private func setupAddressFields() {
        viewModel.addressFields.forEach {
            let input = TextFieldView(id: $0.rawValue)
            addressStackView.addArrangedSubview(input)
            setupInput(input, field: $0, isLast: $0 == viewModel.addressFields.last, viewModel: viewModel)
        }
        billingStackView.addArrangedSubview(addressStackView)
        addressStackView.isHiddenInStackView = !viewModel.isAddressFieldsVisible
    }

    private func setupInput(_ input: TextFieldView, field: Field, isLast: Bool, viewModel: ViewModel) {
        input.title = viewModel.title(for: field)
        input.placeholder = ""
        input.textContentType = viewModel.contentType(for: field)
        input.autocapitalizationType = viewModel.capitalization(for: field)
        input.keyboardType = viewModel.keyboardType(for: field)
        input.autocorrectionType = .no

        input.onTextChanged = { [weak self, field] in
            self?.onTextChanged(field: field)
        }

        input.onEndEditing = { [weak self, field] in
            self?.onEndEditing(field: field)
        }

        input.onBeginEditing = { [weak self, field] in
            self?.onBeginEditing(field: field)
        }

        setupOnTextFieldShouldReturn(field: field, isLast: isLast)
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        setShowsErrorBanner(false)
        setupBillingStackView()
        setupAddressFields()

        applyPrimaryColor()
        applySecondaryColor()

        formFields.forEach {
            $0.inputAccessoryView = formFieldsAccessoryView
        }

        errorLabels.forEach {
            $0.textColor = errorMessageTextColor
        }

        formFields.forEach(self.updateAccessibilityValue)

        updateSupplementaryUI()

        configureAccessibility()
        formFields.forEach {
            $0.adjustsFontForContentSizeCategory = true
        }
        formLabels.forEach {
            $0.adjustsFontForContentSizeCategory = true
        }
        submitButton.titleLabel?.adjustsFontForContentSizeCategory = true

        if  #unavailable(iOS 11) {
            // We'll leave the adjusting scroll view insets job for iOS 11 and later to the layoutMargins + safeAreaInsets here
            automaticallyAdjustsScrollViewInsets = true
        }

        cardNumberTextField.rightView = cardBrandIconImageView
        secureCodeTextField.rightView = cvvInfoButton
        secureCodeTextField.rightViewMode = .always

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillChangeFrame(_:)),
            name: NotificationKeyboardWillChangeFrameNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillHide(_:)),
            name: NotificationKeyboardWillHideFrameNotification,
            object: nil
        )
    }

    public override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()

        if #unavailable(iOS 11) {
            // There's a bug in iOS 10 and earlier which the text field's intrinsicContentSize is returned the value
            // that doesn't take the result of textRect(forBounds:) method into an account for the initial value
            // So we need to invalidate the intrinsic content size here to ask those text fields to calculate their
            // intrinsic content size again

            formFields.forEach {
                $0.invalidateIntrinsicContentSize()
            }
        }
    }

    public override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillAppear(_:)),
            name: NotificationKeyboardWillShowFrameNotification,
            object: nil
        )
    }

    public override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        NotificationCenter().removeObserver(self, name: NotificationKeyboardWillShowFrameNotification, object: nil)
    }

    public override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        if previousTraitCollection?.preferredContentSizeCategory != traitCollection.preferredContentSizeCategory {
            view.setNeedsUpdateConstraints()
        }
    }

    @IBAction private func displayMoreCVVInfo(_ sender: UIButton) {
        guard let viewController = storyboard?.instantiateViewController(withIdentifier: "MoreInformationOnCVVViewController"),
              let moreInformationOnCVVViewController = viewController as? MoreInformationOnCVVViewController else {
            return
        }

        moreInformationOnCVVViewController.preferredCardBrand = cardNumberTextField.cardBrand
        moreInformationOnCVVViewController.delegate = self
        moreInformationOnCVVViewController.modalPresentationStyle = .custom
        moreInformationOnCVVViewController.transitioningDelegate = overlayTransitionDelegate
        moreInformationOnCVVViewController.view.tintColor = view.tintColor
        present(moreInformationOnCVVViewController, animated: true, completion: nil)
    }

    @IBAction private func cancelForm() {
        performCancelingForm()
    }

    @discardableResult
    private func performCancelingForm() -> Bool {
        os_log("Credit Card Form dismissing requested, Asking the delegate what should the form controler do",
               log: uiLogObject,
               type: .default)

        if let delegate = self.delegate {
            delegate.creditCardFormViewControllerDidCancel(self)
            os_log("Canceling form delegate notified", log: uiLogObject, type: .default)
            return true
        } else if let delegateMethod = __delegate?.creditCardFormViewControllerDidCancel {
            delegateMethod(self)
            os_log("Canceling form delegate notified", log: uiLogObject, type: .default)
            return true
        } else {
            os_log("Credit Card Form dismissing requested but there is not delegate to ask. Ignore the request",
                   log: uiLogObject,
                   type: .default)
            return false
        }
    }

    private func makeViewContext() -> ViewContext {
        var context = ViewContext()
        let fields = viewModel.addressFields
        for field in fields {
            switch field {
            default: context[field] = input(for: field)?.text ?? ""
            }
        }

        context.countryCode = viewModel.countryListViewModel.selectedCountry?.code ?? ""
        context.pan = cardNumberTextField.pan
        context.name = cardNameTextField.text ?? ""
        context.expirationMonth = expiryDateTextField.selectedMonth ?? 0
        context.expirationYear = expiryDateTextField.selectedYear ?? 0
        context.securityCode = secureCodeTextField.text ?? ""

        return context
    }

    @IBAction private func requestToken() {
        doneEditing(nil)

        UIAccessibility.post(notification: AccessibilityNotificationAnnouncement, argument: "Submitting payment, please wait")

        startActivityIndicator()
        viewModel.onSubmitButtonPressed(makeViewContext(), publicKey: publicKey) { [weak self] result in
            guard let strongSelf = self else { return }

            strongSelf.stopActivityIndicator()
            switch result {
            case let .success(token):
                os_log("Credit Card Form's Request succeed %{private}@, trying to notify the delegate",
                       log: uiLogObject,
                       type: .default,
                       token.id)
                if let delegate = strongSelf.delegate {
                    delegate.creditCardFormViewController(strongSelf, didSucceedWithToken: token)
                    os_log("Credit Card Form Create Token succeed delegate notified", log: uiLogObject, type: .default)
                } else if let delegate = strongSelf.__delegate {
                    delegate.creditCardFormViewController(strongSelf, didSucceedWithToken: __OmiseToken(token: token))
                    os_log("Credit Card Form Create Token succeed delegate notified", log: uiLogObject, type: .default)
                } else {
                    os_log("There is no Credit Card Form's delegate to notify about the created token", log: uiLogObject, type: .default)
                }
            case let .failure(err):
                strongSelf.handleError(err)
            }
        }
    }

    @objc private func keyboardWillAppear(_ notification: Notification) {
        if hasErrorMessage {
            hasErrorMessage = false
            dismissErrorMessage(animated: true, sender: self)
        }
    }

    @objc func keyboardWillChangeFrame(_ notification: NSNotification) {
        guard let frameEnd = notification.userInfo?[NotificationKeyboardFrameEndUserInfoKey] as? CGRect,
              let frameStart = notification.userInfo?[NotificationKeyboardFrameBeginUserInfoKey] as? CGRect,
              frameEnd != frameStart else {
            return
        }

        let intersectedFrame = contentView.convert(frameEnd, from: nil)

        contentView.contentInset.bottom = intersectedFrame.height
        let bottomScrollIndicatorInset: CGFloat
        if #available(iOS 11.0, *) {
            bottomScrollIndicatorInset = intersectedFrame.height - contentView.safeAreaInsets.bottom
        } else {
            bottomScrollIndicatorInset = intersectedFrame.height
        }
        contentView.scrollIndicatorInsets.bottom = bottomScrollIndicatorInset
    }

    @objc func keyboardWillHide(_ notification: NSNotification) {
        contentView.contentInset.bottom = 0.0
        contentView.scrollIndicatorInsets.bottom = 0.0
    }

    private func handleError(_ error: Error) {
        guard handleErrors else {
            os_log("Credit Card Form's Request failed %{private}@, automatically error handling turned off. Trying to notify the delegate",
                   log: uiLogObject,
                   type: .info,
                   error.localizedDescription)
            if let delegate = self.delegate {
                delegate.creditCardFormViewController(self, didFailWithError: error)
                os_log("Error handling delegate notified", log: uiLogObject, type: .default)
            } else if let delegate = self.__delegate {
                delegate.creditCardFormViewController(self, didFailWithError: error as NSError)
                os_log("Error handling delegate notified", log: uiLogObject, type: .default)
            } else {
                os_log("There is no Credit Card Form's delegate to notify about the error", log: uiLogObject, type: .default)
            }
            return
        }

        os_log("Credit Card Form's Request failed %{private}@, automatically error handling turned on.",
               log: uiLogObject,
               type: .default,
               error.localizedDescription)

        displayError(error)
        hasErrorMessage = true
    }

    private func displayError(_ error: Error) {
        let targetController = targetViewController(forAction: #selector(UIViewController.displayErrorWith(title:message:animated:sender:)),
                                                    sender: self)
        if let targetController = targetController, targetController !== self {
            if let error = error as? OmiseError {
                targetController.displayErrorWith(title: error.bannerErrorDescription,
                                                  message: error.bannerErrorRecoverySuggestion,
                                                  animated: true,
                                                  sender: self)
            } else if let error = error as? LocalizedError {
                targetController.displayErrorWith(title: error.localizedDescription,
                                                  message: error.recoverySuggestion,
                                                  animated: true,
                                                  sender: self)
            } else {
                targetController.displayErrorWith(title: error.localizedDescription,
                                                  message: nil,
                                                  animated: true,
                                                  sender: self)
            }
        } else {
            let errorTitle: String
            let errorMessage: String?
            if let error = error as? OmiseError {
                errorTitle = error.bannerErrorDescription
                errorMessage = error.bannerErrorRecoverySuggestion
            } else if let error = error as? LocalizedError {
                errorTitle = error.localizedDescription
                errorMessage = error.recoverySuggestion
            } else {
                errorTitle = error.localizedDescription
                errorMessage = nil
            }

            errorTitleLabel.text = errorTitle
            errorMessageLabel.text = errorMessage

            errorMessageLabel.isHidden = errorMessage == nil
            emptyErrorMessageConstraint.priority = errorMessage == nil ? UILayoutPriority(999) : UILayoutPriority(1)
            errorBannerView.layoutIfNeeded()

            setShowsErrorBanner(true)
        }
    }

    private func setShowsErrorBanner(_ showsErrorBanner: Bool, animated: Bool = true) {
        hidingErrorBannerConstraint.isActive = !showsErrorBanner

        let animationBlock = {
            self.errorBannerView.alpha = showsErrorBanner ? 1.0 : 0.0
            self.contentView.layoutIfNeeded()
        }

        if animated {
            UIView.animate(withDuration: TimeInterval(NavigationControllerHideShowBarDuration),
                           delay: 0.0,
                           options: [.layoutSubviews],
                           animations: animationBlock)
        } else {
            animationBlock()
        }
    }

    @IBAction private func dismissErrorBanner(_ sender: Any) {
        setShowsErrorBanner(false)
    }

    private func updateSupplementaryUI() {
        updateSubmitButtonState()

        let cardBrandIconName: String?
        switch cardNumberTextField.cardBrand {
        case .visa?:
            cardBrandIconName = "Visa"
        case .masterCard?:
            cardBrandIconName = "Mastercard"
        case .jcb?:
            cardBrandIconName = "JCB"
        case .amex?:
            cardBrandIconName = "AMEX"
        case .diners?:
            cardBrandIconName = "Diners"
        default:
            cardBrandIconName = nil
        }
        cardBrandIconImageView.image = cardBrandIconName.flatMap { UIImage(named: $0, in: .omiseSDK, compatibleWith: nil) }
        cardNumberTextField.rightViewMode = cardBrandIconImageView.image != nil ? .always : .never
    }

    private func startActivityIndicator() {
        requestingIndicatorView.startAnimating()
        submitButton.isEnabled = false
        view.isUserInteractionEnabled = false
    }

    private func stopActivityIndicator() {
        requestingIndicatorView.stopAnimating()
        submitButton.isEnabled = true
        view.isUserInteractionEnabled = true
    }

    private func applyPrimaryColor() {
        guard isViewLoaded else {
            return
        }

        formFields.forEach {
            $0.textColor = currentPrimaryColor
        }
        formLabels.forEach {
            $0.textColor = currentPrimaryColor
        }

        let textFields: [UIView] =
        billingStackView.arrangedSubviews.filter { $0.isKind(of: TextFieldView.self) } +
        addressStackView.arrangedSubviews.filter { $0.isKind(of: TextFieldView.self) }

        textFields.forEach {
            if let input = $0 as? TextFieldView {
                input.textColor = currentPrimaryColor
            }
        }

    }

    private func applySecondaryColor() {
        guard isViewLoaded else {
            return
        }

        formFields.forEach {
            $0.borderColor = currentSecondaryColor
            $0.placeholderTextColor = currentSecondaryColor
        }

        let textFields: [UIView] =
        billingStackView.arrangedSubviews.filter { $0.isKind(of: TextFieldView.self) } +
        addressStackView.arrangedSubviews.filter { $0.isKind(of: TextFieldView.self) }

        textFields.forEach {
            if let input = $0 as? TextFieldView {
                input.titleColor = preferredPrimaryColor
                input.borderColor = currentSecondaryColor
                input.placeholderTextColor = currentSecondaryColor
            }
        }
    }

    fileprivate func associatedErrorLabelOf(_ textField: OmiseTextField) -> UILabel? {
        switch textField {
        case cardNumberTextField:
            return creditCardNumberErrorLabel
        case cardNameTextField:
            return cardHolderNameErrorLabel
        case expiryDateTextField:
            return cardExpiryDateErrorLabel
        case secureCodeTextField:
            return cardSecurityCodeErrorLabel
        default:
            return nil
        }
    }

    private func validateField(_ textField: OmiseTextField) {
        guard let errorLabel = associatedErrorLabelOf(textField) else {
            return
        }
        do {
            try textField.validate()
            errorLabel.alpha = 0.0
        } catch {
            errorLabel.text = validationErrorText(for: textField, error: error)
            errorLabel.alpha = errorLabel.text != "-" ? 1.0 : 0.0
        }
    }

    private func validationErrorText(for textField: UITextField, error: Error) -> String {
        switch (error, textField) {
        case (OmiseTextFieldValidationError.emptyText, _):
            return "-" // We need to set the error label some string in order to have it retains its height

        case (OmiseTextFieldValidationError.invalidData, cardNumberTextField):
            return NSLocalizedString(
                "credit-card-form.card-number-field.invalid-data.error.text",
                tableName: "Error",
                bundle: .omiseSDK,
                value: "Credit card number is invalid",
                comment: "An error text displayed when the credit card number is invalid"
            )
        case (OmiseTextFieldValidationError.invalidData, cardNameTextField):
            return NSLocalizedString(
                "credit-card-form.card-holder-name-field.invalid-data.error.text",
                tableName: "Error",
                bundle: .omiseSDK,
                value: "Card holder name is invalid",
                comment: "An error text displayed when the card holder name is invalid"
            )
        case (OmiseTextFieldValidationError.invalidData, expiryDateTextField):
            return NSLocalizedString(
                "credit-card-form.expiry-date-field.invalid-data.error.text",
                tableName: "Error",
                bundle: .omiseSDK,
                value: "Card expiry date is invalid",
                comment: "An error text displayed when the expiry date is invalid"
            )
        case (OmiseTextFieldValidationError.invalidData, secureCodeTextField):
            return NSLocalizedString(
                "credit-card-form.security-code-field.invalid-data.error.text",
                tableName: "Error",
                bundle: .omiseSDK,
                value: "CVV code is invalid",
                comment: "An error text displayed when the security code is invalid"
            )

        case (_, cardNumberTextField),
            (_, cardNameTextField),
            (_, expiryDateTextField),
            (_, secureCodeTextField):
            return error.localizedDescription
        default:
            return "-"
        }
    }
}

// MARK: - Fields Accessory methods
extension CreditCardFormViewController {

    @IBAction private func validateTextFieldDataOf(_ sender: OmiseTextField) {
        let duration = TimeInterval(NavigationControllerHideShowBarDuration)
        UIView.animate(withDuration: duration,
                       delay: 0.0,
                       options: [.curveEaseInOut, .allowUserInteraction, .beginFromCurrentState, .layoutSubviews]) {
            self.validateField(sender)
        }
        sender.borderColor = currentSecondaryColor
    }

    @IBAction private func updateInputAccessoryViewFor(_ sender: OmiseTextField) {
        if let errorLabel = associatedErrorLabelOf(sender) {
            let duration = TimeInterval(NavigationControllerHideShowBarDuration)
            UIView.animate(withDuration: duration,
                           delay: 0.0,
                           options: [.curveEaseInOut, .allowUserInteraction, .beginFromCurrentState, .layoutSubviews]) {
                errorLabel.alpha = 0.0
            }
        }

        sender.borderColor = view.tintColor
        updateInputAccessoryViewWithFirstResponder(sender)
    }

    @IBAction private func gotoPreviousField(_ button: UIBarButtonItem) {
        gotoPreviousField()
    }

    @IBAction private func gotoNextField(_ button: UIBarButtonItem) {
        gotoNextField()
    }

    @IBAction private func doneEditing(_ button: UIBarButtonItem?) {
        doneEditing()
    }
}

// MARK: - Accessibility
extension CreditCardFormViewController {

    @IBAction private func updateAccessibilityValue(_ sender: OmiseTextField) {
        updateSupplementaryUI()
    }

    // swiftlint:disable:next function_body_length
    private func configureAccessibility() {
        formLabels.forEach {
            $0.adjustsFontForContentSizeCategory = true
        }
        formFields.forEach {
            $0.adjustsFontForContentSizeCategory = true
        }

        submitButton.titleLabel?.adjustsFontForContentSizeCategory = true

        let fields = [
            cardNumberTextField,
            cardNameTextField,
            expiryDateTextField,
            secureCodeTextField
        ] as [OmiseTextField]

        // swiftlint:disable:next function_body_length
        func accessiblityElementAfter(
            _ element: NSObjectProtocol?,
            matchingPredicate predicate: (OmiseTextField) -> Bool,
            direction: AccessibilityCustomRotorDirection
        ) -> NSObjectProtocol? {
            guard let element = element else {
                switch direction {
                case .previous:
                    return fields.reversed().first(where: predicate)?.accessibilityElements?.last as? NSObjectProtocol
                    ?? fields.reversed().first(where: predicate)
                case .next:
                    fallthrough
                @unknown default:
                    return fields.first(where: predicate)?.accessibilityElements?.first as? NSObjectProtocol
                    ?? fields.first(where: predicate)
                }
            }

            let fieldOfElement = fields.first { field in
                guard let accessibilityElements = field.accessibilityElements as? [NSObjectProtocol] else {
                    return element === field
                }

                return accessibilityElements.contains { $0 === element }
            } ?? cardNumberTextField! // swiftlint:disable:this force_unwrapping

            func filedAfter(
                _ field: OmiseTextField,
                matchingPredicate predicate: (OmiseTextField) -> Bool,
                direction: AccessibilityCustomRotorDirection
            ) -> OmiseTextField? {
                guard let indexOfField = fields.firstIndex(of: field) else { return nil }
                switch direction {
                case .previous:
                    return fields[fields.startIndex..<indexOfField].reversed().first(where: predicate)
                case .next: fallthrough
                @unknown default:
                    return fields[fields.index(after: indexOfField)...].first(where: predicate)
                }
            }

            let nextField = filedAfter(fieldOfElement, matchingPredicate: predicate, direction: direction)

            guard let currentAccessibilityElements = (fieldOfElement.accessibilityElements as? [NSObjectProtocol]),
                  let indexOfAccessibilityElement = currentAccessibilityElements.firstIndex(where: { $0 === element }) else {
                switch direction {
                case .previous:
                    return nextField?.accessibilityElements?.last as? NSObjectProtocol ?? nextField
                case .next:
                    fallthrough
                @unknown default:
                    return nextField?.accessibilityElements?.first as? NSObjectProtocol ?? nextField
                }
            }

            switch direction {
            case .previous:
                if predicate(fieldOfElement) && indexOfAccessibilityElement > currentAccessibilityElements.startIndex {
                    return currentAccessibilityElements[currentAccessibilityElements.index(before: indexOfAccessibilityElement)]
                } else {
                    return nextField?.accessibilityElements?.last as? NSObjectProtocol ?? nextField
                }
            case .next:
                fallthrough
            @unknown default:
                if predicate(fieldOfElement) && indexOfAccessibilityElement < currentAccessibilityElements.endIndex - 1 {
                    return currentAccessibilityElements[currentAccessibilityElements.index(after: indexOfAccessibilityElement)]
                } else {
                    return nextField?.accessibilityElements?.first as? NSObjectProtocol ?? nextField
                }
            }
        }

        accessibilityCustomRotors = [
            UIAccessibilityCustomRotor(name: "Fields") { (predicate) -> UIAccessibilityCustomRotorItemResult? in
                return accessiblityElementAfter(predicate.currentItem.targetElement,
                                                matchingPredicate: { _ in true },
                                                direction: predicate.searchDirection)
                .map { UIAccessibilityCustomRotorItemResult(targetElement: $0, targetRange: nil) }
            },
            UIAccessibilityCustomRotor(name: "Invalid Data Fields") { (predicate) -> UIAccessibilityCustomRotorItemResult? in
                return accessiblityElementAfter(predicate.currentItem.targetElement,
                                                matchingPredicate: { !$0.isValid },
                                                direction: predicate.searchDirection)
                .map { UIAccessibilityCustomRotorItemResult(targetElement: $0, targetRange: nil) }
            }
        ]
    }

    public override func accessibilityPerformMagicTap() -> Bool {
        guard isInputDataValid else {
            return false
        }

        requestToken()
        return true
    }

    public override func accessibilityPerformEscape() -> Bool {
        return performCancelingForm()
    }
}

extension CreditCardFormViewController: MoreInformationOnCVVViewControllerDelegate {
    func moreInformationOnCVVViewControllerDidAskToClose(_ controller: MoreInformationOnCVVViewController) {
        dismiss(animated: true, completion: nil)
    }
}

private extension CreditCardFormViewController {
    func updateSubmitButtonState() {
        let valid = isInputDataValid
        submitButton?.isEnabled = valid && viewModel.isSubmitButtonEnabled(makeViewContext())

        if valid {
            submitButton.accessibilityTraits.remove(UIAccessibilityTraits.notEnabled)
        } else {
            submitButton.accessibilityTraits.insert(UIAccessibilityTraits.notEnabled)
        }
    }

    func updateError(for field: Field) {
        guard let input = input(for: field) else { return }
        input.error = viewModel.error(for: field, validate: input.text)
    }

    func input(for field: Field) -> TextFieldView? {
        let arrangedSubviews = addressStackView.arrangedSubviews + billingStackView.arrangedSubviews
        for input in arrangedSubviews {
            guard let input = input as? TextFieldView, input.identifier == field.rawValue else {
                continue
            }
            return input
        }
        return nil
    }

    func input(after input: TextFieldView) -> TextFieldView? {
        guard
            let inputField = Field(rawValue: input.identifier),
            let index = viewModel.addressFields.firstIndex(of: inputField),
            let nextField = viewModel.addressFields.at(index + 1),
            let nextInput = self.input(for: nextField) else {
            return nil
        }

        if nextInput.textFieldUserInteractionEnabled {
            return nextInput
        } else {
            return self.input(after: nextInput)
        }
    }

    func hideErrorIfNil(field: Field) {
        if let input = input(for: field) {
            let error = viewModel.error(for: field, validate: input.text)
            if error == nil {
                input.error = nil
            }
        }
    }

    @objc func hideKeyboard() {
        self.view.endEditing(true)
    }

    func onTextChanged(field: Field) {
        updateSubmitButtonState()
        hideErrorIfNil(field: field)
    }

    func onEndEditing(field: Field) {
        updateError(for: field)
    }

    func onBeginEditing(field: Field) {
        switch field {
        default: return
        }
    }

    func onReturnKeyTapped(field: Field) -> Bool {
        guard let input = input(for: field) else { return true }
        self.onKeboardNextTapped(input: input)
        return false
    }

    func setupOnTextFieldShouldReturn(field: Field, isLast: Bool) {
        guard let input = input(for: field) else { return }

        if isLast {
            input.returnKeyType = .next
            input.onTextFieldShouldReturn = { [weak self, weak input] in
                guard let self = self, let input = input else { return true }
                self.onKeyboardDoneTapped(input: input)
                return true
            }
        } else {
            input.returnKeyType = .next
            input.onTextFieldShouldReturn = { [weak self, weak input] in
                guard let self = self, let input = input else { return true }
                self.onKeboardNextTapped(input: input)
                return false
            }
        }
    }

    func onKeboardNextTapped(input: TextFieldView) {
        if let nextInput = self.input(after: input) {
            _ = nextInput.becomeFirstResponder()
        }
    }

    func onKeyboardDoneTapped(input: TextFieldView) {
        if submitButton.isEnabled {
            requestToken()
        } else {
            showAllErrors()
            goToFirstInvalidField()
        }
    }

    func goToFirstInvalidField() {
        for field in viewModel.addressFields {
            if let input = input(for: field), input.error != nil {
                input.becomeFirstResponder()
                return
            }
        }

    }

    func showAllErrors() {
        for field in viewModel.addressFields {
            updateError(for: field)
        }
    }

}
