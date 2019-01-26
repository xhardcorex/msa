//
//  ComunityDetailsViewController.swift
//  MSA
//
//  Created by Andrey Krit on 8/22/18.
//  Copyright © 2018 Pavlo Kharambura. All rights reserved.
//

import UIKit
import SVProgressHUD

protocol UserCommunityViewProtocol: class {
    func reloadData()
    func showAlert(for user: UserVO)
}

class UserCommunityViewController: UIViewController, UserCommunityViewProtocol, UISearchBarDelegate {
    
    @IBOutlet weak var stateSegmentedControl: UISegmentedControl!
    @IBOutlet weak var userCommunityTableView: UITableView!
    @IBOutlet weak var searchBar: UISearchBar!
    
    private let refreshControl = UIRefreshControl()
    
    var presenter: UserCommunityPresenterProtocol!

    override func viewDidLoad() {
        super.viewDidLoad()
        userCommunityTableView.delegate = self
        userCommunityTableView.dataSource = self
        configureRefresh()
        presenter.start()
        searchBar.delegate = self
        if presenter.isTrainer {
            stateSegmentedControl.insertSegment(withTitle: "Спортсмены", at: 3, animated: false)
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationController?.navigationBar.shadowImage = UIImage()
        //configureSearchController()
        configureSegmentedControl()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(true)
    }
    
    func reloadData() {
        SVProgressHUD.dismiss()
        DispatchQueue.main.async { [weak self] in
            self?.userCommunityTableView.reloadData()
            self?.refreshControl.endRefreshing()
        }
    }
    
    func showAlert(for user: UserVO) {
        let alert = UIAlertController(title: nil, message: "Вы дейсвительно хотите удалить из запросов/друзей? ", preferredStyle: .actionSheet)
        let deleteAction = UIAlertAction(title: "Удалить", style: .destructive) { [weak self] _ in
            self?.presenter.deleteAction(for: user)
        }
        let cancelAction = UIAlertAction(title: "Отмена", style: .cancel, handler: nil)
        alert.addAction(deleteAction)
        alert.addAction(cancelAction)
        present(alert, animated: true)
    }
    
    private func configureSearchBar() {
        searchBar.backgroundImage = nil
    }
    
    private func configureRefresh() {
//        let attributes = [NSAttributedStringKey.foregroundColor: darkCyanGreen,
//                          NSAttributedStringKey.font: UIFont(name: "Rubik-Medium", size: 14)!]
//        refreshControl.attributedTitle = NSAttributedString(string: "Синхронизация ...", attributes: attributes)
        if #available(iOS 10.0, *) {
            userCommunityTableView.refreshControl = refreshControl
        } else {
            userCommunityTableView.addSubview(refreshControl)
        }
        refreshControl.addTarget(self, action: #selector(refreshData(_:)), for: .valueChanged)
    }
    
    @objc private func refreshData(_ sender: Any) {
        presenter.refresh()
    }
    
//    private func hideableNavigationBar(_ hide: Bool) {
//        if #available(iOS 11.0, *) {
//            navigationItem.hidesSearchBarWhenScrolling = hide
//        }
//    }
    
    private func configureSegmentedControl() {
        stateSegmentedControl.tintColor = UIColor.lightWhiteBlue
        stateSegmentedControl.setTitleTextAttributes([NSAttributedStringKey.font: Fonts.medium(13)],
                                                for: .normal)
        
    }
    
    private func moveToUserViewController(user: UserVO) {
        let destinationVC = UIStoryboard(name: "Community", bundle: nil).instantiateViewController(withIdentifier: "ProfileViewController") as! ProfileViewController
        destinationVC.profilePresenter = presenter.createProfilePresenter(user: user, for: destinationVC)
        navigationController?.pushViewController(destinationVC, animated: true)
    }

    @IBAction func segmetedControlDidTapped(_ sender: UISegmentedControl) {
        presenter.setDataSource(with: searchBar.text, and: sender.selectedSegmentIndex)
    }
}


//MARK: - TableViewDelegate & DataSource

extension UserCommunityViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
       return presenter.userCommunityDataSource.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "PersonTableViewCell") as! PersonTableViewCell
        cell.state = .caseMyCommunity
        cell.configure(with: presenter.userCommunityDataSource[indexPath.row], userCommunityState: presenter.state)
        cell.acceptButtonHandler = { [weak self] in
            SVProgressHUD.show()
            self?.presenter.acceptRequest(atIndex: indexPath.row)}
        cell.deleteButtonHandler = { [weak self] in self?.presenter.deleteButtonTapped(atIndex: indexPath.row)}
      return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        moveToUserViewController(user: presenter.userCommunityDataSource[indexPath.row])
    }
}

//MARK: - Search Results Updating

extension UserCommunityViewController: UISearchResultsUpdating {
    
    func searchBarTextDidEndEditing(_ searchBar: UISearchBar) {
    
    }
    
    func searchBarTextDidBeginEditing(_ searchBar: UISearchBar) {
        
    }
    
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
         presenter.setDataSource(with: searchText, and:stateSegmentedControl.selectedSegmentIndex)
    }
    
    func updateSearchResults(for searchController: UISearchController) {
        presenter.setDataSource(with: searchController.searchBar.text, and:stateSegmentedControl.selectedSegmentIndex)
    }
}
