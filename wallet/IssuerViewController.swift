//
//  IssuerViewController.swift
//  wallet
//
//  Created by Chris Downie on 12/19/16.
//  Copyright © 2016 Learning Machine, Inc. All rights reserved.
//

import UIKit
import Blockcerts

class IssuerViewController: UIViewController {
    var managedIssuer: ManagedIssuer?
    var certificates = [Certificate]()
    
    fileprivate var certificateTableController : IssuerTableViewController!

    override func viewDidLoad() {
        super.viewDidLoad()
        view.layoutMargins = UIEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
        
        navigationItem.backBarButtonItem = UIBarButtonItem(title: "", style: .plain, target: nil, action: nil)
        navigationItem.rightBarButtonItem = UIBarButtonItem(image: #imageLiteral(resourceName: "icon_info"), style: .plain, target: self, action: #selector(displayIssuerInfo))

        certificateTableController = IssuerTableViewController()
        certificateTableController.managedIssuer = managedIssuer
        certificateTableController.certificates = certificates
        certificateTableController.delegate = self
        
        certificateTableController.willMove(toParentViewController: self)
        
        self.addChildViewController(certificateTableController)
        certificateTableController.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(certificateTableController.view)
        
        certificateTableController.didMove(toParentViewController: self)
        
        
        let views : [String : UIView] = [
            "table": certificateTableController.view
        ]
        let verticalConstraints = NSLayoutConstraint.constraints(withVisualFormat: "V:|[table]|", options: .alignAllCenterX, metrics: nil, views: views)
        let horizontalTableConstraints = NSLayoutConstraint.constraints(withVisualFormat: "|[table]|", options: .alignAllCenterX, metrics: nil, views: views)
        
        NSLayoutConstraint.activate(verticalConstraints)
        NSLayoutConstraint.activate(horizontalTableConstraints)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        if let tableView = certificateTableController.tableView,
            let selectedPath = tableView.indexPathForSelectedRow {
            tableView.deselectRow(at: selectedPath, animated: true)
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        AppDelegate.instance.styleApplicationDefault()
    }
    
    var activityIndicator: UIActivityIndicatorView?
    
    func showActivityIndicator() {
        guard self.activityIndicator == nil else { return }
        let activityIndicator = UIActivityIndicatorView(activityIndicatorStyle: .whiteLarge)
        activityIndicator.startAnimating()
        activityIndicator.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
        activityIndicator.layer.cornerRadius = 10
        activityIndicator.backgroundColor = .gray
        activityIndicator.alpha = 0.8
        
        let center: CGPoint
        if let keyView: UIView = UIApplication.shared.keyWindow?.rootViewController?.view {
            center = keyView.convert(keyView.center, to: view)
        } else {
            center = CGPoint(x: view.center.x, y: view.center.y - 32)
        }
        activityIndicator.center = center
        
        view.addSubview(activityIndicator)
        self.activityIndicator = activityIndicator
    }
    
    func hideActivityIndicator() {
        guard let activityIndicator = activityIndicator else { return }
        activityIndicator.removeFromSuperview()
        self.activityIndicator = nil
    }
    
    @objc func displayIssuerInfo() {
        guard let managedIssuer = managedIssuer else {
            return
        }
        Logger.main.info("More info tapped on the Issuer display.")
        let controller = IssuerMetadataViewController(issuer: managedIssuer)
        controller.delegate = self
        let navController = UINavigationController(rootViewController: controller);
        present(navController, animated: true, completion: nil)
    }
    
    @objc func addCertificateTapped() {
        Logger.main.info("Add certificate button tapped")
        
        let addCertificateFromFile = NSLocalizedString("Import Credential from File", comment: "Contextual action. Tapping this prompts the user to add a file from a document provider.")
        let addCertificateFromURL = NSLocalizedString("Import Credential from URL", comment: "Contextual action. Tapping this prompts the user for a URL to pull the certificate from.")
        let cancelAction = NSLocalizedString("Cancel", comment: "Cancel action")
        
        
        let alertController = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        
        alertController.addAction(UIAlertAction(title: addCertificateFromFile, style: .default, handler: { [weak self] _ in
            Logger.main.info("User has chosen to add a certificate from file")
            
            let controller = UIDocumentPickerViewController(documentTypes: ["public.json"], in: .import)
            controller.delegate = self
            controller.modalPresentationStyle = .formSheet

            self?.present(controller, animated: true, completion: { AppDelegate.instance.styleApplicationAlternate() })
        }))
        
        alertController.addAction(UIAlertAction(title: addCertificateFromURL, style: .default, handler: { [weak self] _ in
            Logger.main.info("User has chosen to add a certificate from URL")
            
            let certificateURLPrompt = NSLocalizedString("What's the URL of the credential?", comment: "Certificate URL prompt for importing a certificate.")
            let importAction = NSLocalizedString("Import", comment: "Import certificate action")
            
            let urlPrompt = UIAlertController(title: nil, message: certificateURLPrompt, preferredStyle: .alert)
            urlPrompt.addTextField(configurationHandler: { (textField) in
                textField.placeholder = NSLocalizedString("URL", comment: "URL placeholder text")
            })
            
            urlPrompt.addAction(UIAlertAction(title: importAction, style: .default, handler: { (_) in
                guard let urlField = urlPrompt.textFields?.first,
                    let trimmedText = urlField.text?.trimmingCharacters(in: CharacterSet.whitespaces),
                    let url = URL(string: trimmedText) else {
                        return
                }
                Logger.main.info("User attempting to add a certificate from \(url).")
                
                _ = self?.addCertificate(from: url)
            }))
            
            urlPrompt.addAction(UIAlertAction(title: cancelAction, style: .cancel, handler: { _ in
                Logger.main.info("User cancelled adding a certificate from URL.")
            }))
            
            self?.present(urlPrompt, animated: true, completion: nil)
        }))
        
        alertController.addAction(UIAlertAction(title: cancelAction, style: .cancel, handler: nil))
        
        present(alertController, animated: true, completion: nil)
    }
    
    func navigateTo(certificate: Certificate, animated: Bool = true) {
        let controller = CertificateViewController(certificate: certificate)
        controller.delegate = self

        OperationQueue.main.addOperation {
            self.navigationController?.pushViewController(controller, animated: animated)
        }
    }
    
    func redirect(to certificate: Certificate) {
        let data = [
            "certificate": certificate
        ]
        OperationQueue.main.addOperation {
            self.navigationController?.popViewController(animated: true)
            NotificationCenter.default.post(name: NotificationNames.redirectToCertificate, object: self, userInfo: data)
        }
    }
    

    // Certificate handling
    func addCertificate(from url: URL) {
        showActivityIndicator()
        defer {
            hideActivityIndicator()
        }
        guard let certificate = CertificateManager().load(certificateAt: url) else {
            Logger.main.error("Failed to load certificate from \(url)")
            
            let title = NSLocalizedString("Invalid Credential", comment: "Title for an alert when importing an invalid certificate")
            let message = NSLocalizedString("That file doesn't appear to be a valid credential.", comment: "Message in an alert when importing an invalid certificate")
            alertError(localizedTitle: title, localizedMessage: message)
            
            return
        }
        
        saveCertificateIfOwned(certificate: certificate)
    }
    
    func importCertificate(from data: Data?) {
        showActivityIndicator()
        defer {
            hideActivityIndicator()
        }
        guard let data = data else {
            Logger.main.error("Failed to load a certificate from file. Data is nil.")
            
            let title = NSLocalizedString("Invalid Credential", comment: "Imported certificate didn't parse title")
            let message = NSLocalizedString("That doesn't appear to be a valid credential file.", comment: "Imported title didn't parse message")
            alertError(localizedTitle: title, localizedMessage: message)
            return
        }
        
        do {
            let certificate = try CertificateParser.parse(data: data)
            
            saveCertificateIfOwned(certificate: certificate)
        } catch {
            Logger.main.error("Importing failed with error: \(error)")
            
            let title = NSLocalizedString("Invalid Credential", comment: "Imported certificate didn't parse title")
            let message = NSLocalizedString("That doesn't appear to be a valid credential file.", comment: "Imported title didn't parse message")
            alertError(localizedTitle: title, localizedMessage: message)
            return
        }
    }
    
    func saveCertificateIfOwned(certificate: Certificate) {
        // TODO: Check ownership based on the flag.
        
        let manager = CertificateManager()
        manager.save(certificate: certificate)
        certificates = manager.loadCertificates()
        certificateTableController.certificates = certificates
        
        if certificate.issuer.id == managedIssuer?.issuer?.id {
            navigateTo(certificate: certificate)
            
            OperationQueue.main.addOperation { [weak self] in
                self?.certificateTableController.tableView.reloadData()
            }
        } else {
            redirect(to: certificate)
        }
    }
    
    func alertError(localizedTitle: String, localizedMessage: String) {
        let okay = NSLocalizedString("OK", comment: "OK dismiss action")
        
        let prompt = UIAlertController(title: localizedTitle, message: localizedMessage, preferredStyle: .alert);
        prompt.addAction(UIAlertAction(title: okay, style: .cancel, handler: nil))
        
        present(prompt, animated: true, completion: nil)
    }
}

extension IssuerViewController : IssuerTableViewControllerDelegate {
    func show(certificate: Certificate) {
        navigateTo(certificate: certificate)
    }
}

extension IssuerViewController : CertificateViewControllerDelegate {
    func delete(certificate: Certificate) {
        let possibleIndex = certificates.index(where: { (cert) -> Bool in
            return cert.assertion.uid == certificate.assertion.uid
        })
        guard let index = possibleIndex else {
            return
        }
        guard let certificateFilename = certificate.filename else {
            Logger.main.error("Something went wrong with generating a filename for \(certificate.id)")
            return
        }
        
        let documentsDirectory = Paths.certificatesDirectory
        let filePath = URL(fileURLWithPath: certificateFilename, relativeTo: documentsDirectory)
        
        let coordinator = NSFileCoordinator()
        var coordinationError : NSError?
        coordinator.coordinate(writingItemAt: filePath, options: [.forDeleting], error: &coordinationError, byAccessor: { [weak self] (file) in
            
            do {
                try FileManager.default.removeItem(at: filePath)
                if let realSelf = self {
                    realSelf.certificates.remove(at: index)
                    if realSelf.certificateTableController != nil {
                        realSelf.certificateTableController.certificates = realSelf.certificates
                        realSelf.certificateTableController.tableView.reloadData()
                    }
                }
            } catch {
                Logger.main.error("Failed to delete certificate: \(certificate.id) with error: \(error)")
                
                let title = NSLocalizedString("Couldn't delete file", comment: "Generic error title. We couldn't delete a certificate.")
                let message = NSLocalizedString("Something went wrong when deleting that certificate.", comment: "Generic error description. We couldn't delete a certificate.")
                let okay = NSLocalizedString("OK", comment: "Confirm action")
                
                
                let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
                alertController.addAction(UIAlertAction(title: okay, style: .default, handler: nil))
                self?.present(alertController, animated: true, completion: nil)
            }
        })
        
        if let error = coordinationError {
            Logger.main.error("Coordination failed with \(error)")
        } else {
            Logger.main.info("Coordination went fine.")
        }
    }
}

extension IssuerViewController : UIDocumentPickerDelegate {
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentAt url: URL) {
        let data = try? Data(contentsOf: url)
        
        importCertificate(from: data)
    }
}

