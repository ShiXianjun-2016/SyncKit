//
//  QSCompanyTableViewController.swift
//  SyncKitRealmSwiftExample
//
//  Created by Manuel Entrena on 01/09/2017.
//  Copyright © 2017 Manuel Entrena. All rights reserved.
//

import UIKit
import RealmSwift
import SyncKit

class QSCompanyTableViewController: UITableViewController {
    
    var realm: Realm!
    var synchronizer: QSCloudKitSynchronizer!
    
    var notificationToken: NotificationToken!
    
    @IBOutlet weak var syncButton: UIButton?
    @IBOutlet weak var indicatorView: UIActivityIndicatorView?
    
    var companies: Results<QSCompany>?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        companies = realm.objects(QSCompany.self).sorted(byKeyPath: "sortIndex")
        
        notificationToken = companies?.addNotificationBlock({ [weak self] (change) in
            switch change {
            case .error(_):
                
                print("Realm error")
                break
            case .update(_, let deletions, let insertions, let modifications):
                
                self?.tableView.beginUpdates()
                self?.tableView.deleteRows(at: deletions.map { IndexPath(row: $0, section: 0) }, with: .automatic)
                self?.tableView.insertRows(at: insertions.map { IndexPath(row: $0, section: 0) }, with: .automatic)
                self?.tableView.reloadRows(at: modifications.map { IndexPath(row: $0, section: 0) }, with: .automatic)
                self?.tableView.endUpdates()
                
            default:
                
                self?.tableView.reloadData()
            }
        })
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        clearsSelectionOnViewWillAppear = splitViewController?.isCollapsed ?? true
    }
    
    @IBAction func insertNewCompany() {
        
        let alertController = UIAlertController(title: "New company", message: nil, preferredStyle: .alert)
        alertController.addTextField { (textField) in
            textField.placeholder = "Enter company's name"
        }
        alertController.addAction(UIAlertAction(title: "Add", style: .default, handler: { (action) in
            
            self.createCompany(name: alertController.textFields!.first!.text!)
        }))
        
        present(alertController, animated: true, completion: nil)
    }
    
    func createCompany(name: String) {
        
        let company = QSCompany()
        company.name = name
        company.identifier = NSUUID().uuidString
        company.sortIndex.value = companies!.count
        
        realm.beginWrite()
        realm.add(company)
        try! realm.commitWrite()
    }
    
    @IBAction func synchronize() {
        
        syncButton?.isHidden = true
        indicatorView?.startAnimating()
        
        synchronizer.synchronize { [weak self] (error) in
            
            self?.syncButton?.isHidden = false
            self?.indicatorView?.stopAnimating()
            
            if let error = error {
                let alertController = UIAlertController(title: "Error", message: "Error: \(error)", preferredStyle: .alert)
                alertController.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                self?.present(alertController, animated: true, completion: nil)
            }
        }
    }
    
    @IBAction func clearAll() {
    
        synchronizer.eraseRemoteAndLocalData { [weak self] (error) in
            
            if let error = error {
                print("Error: \(error)")
            } else {
                DispatchQueue.main.async {
                    guard let strongSelf = self else { return }
                    
                    strongSelf.realm.beginWrite()
                    for company in strongSelf.companies! {
                        strongSelf.realm.delete(company)
                    }
                    
                    for employee in strongSelf.realm.objects(QSEmployee.self) {
                        strongSelf.realm.delete(employee)
                    }
                    
                    try? strongSelf.realm.commitWrite()
                }
            }
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        if segue.identifier == "showEmployees" {
            
            let indexPath = tableView.indexPathForSelectedRow!
            let company = self.companies![indexPath.row]
            
            let controller = segue.destination as! QSEmployeeTableViewController
            controller.realm = realm
            controller.company = company
            controller.navigationItem.leftBarButtonItem = splitViewController?.displayModeButtonItem
            controller.navigationItem.leftItemsSupplementBackButton = true
        }
    }
    
    // MARK : TableView
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        return companies!.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell")!
        
        let company = companies![indexPath.row]
        
        cell.textLabel?.text = company.name
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        
        return true
    }
    
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        
        if editingStyle == .delete {
            
            let company = companies![indexPath.row]
            try! realm.write {
                realm.delete(company)
            }
        }
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        let company = companies![indexPath.row]
        performSegue(withIdentifier: "showEmployees", sender: company)
        
        tableView.deselectRow(at: indexPath, animated: true)
    }
    
}