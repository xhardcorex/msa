//
//  ExercisesInfoViewController.swift
//  MSA
//
//  Created by Pavlo Kharambura on 6/19/18.
//  Copyright © 2018 Pavlo Kharambura. All rights reserved.
//

import UIKit
import AVKit
import AVFoundation
import RealmSwift

class ExercisesInfoViewController: UIViewController {

    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var editButton: UIBarButtonItem!
    
    var execise: Exercise? = nil
    
    override func viewDidLoad() {
        super.viewDidLoad()

        self.navigationController?.navigationBar.titleTextAttributes = [.font: UIFont(name: "Rubik-Medium", size: 17)!]
        configureTableView()
        // Do any additional setup after loading the view.
    }

    func configureTableView() {
        tableView.delegate = self
        tableView.dataSource = self
        self.tableView.register(UINib(nibName: "TextTableViewCell", bundle: nil), forCellReuseIdentifier: "TextTableViewCell")
        self.tableView.register(UINib(nibName: "ImagesTableViewCell", bundle: nil), forCellReuseIdentifier: "ImagesTableViewCell")
        self.tableView.register(UINib(nibName: "PlayVideoTableViewCell", bundle: nil), forCellReuseIdentifier: "PlayVideoTableViewCell")
        self.tableView.register(UINib(nibName: "TextViewTableViewCell", bundle: nil), forCellReuseIdentifier: "TextViewTableViewCell")
        tableView.separatorColor = .clear

    }
    
    override func viewWillAppear(_ animated: Bool) {
        execise = RealmManager.shared.getArray(ofType: Exercise.self, filterWith: NSPredicate(format: "id = %d", execise?.id ?? 0)).first
        self.navigationController?.navigationBar.titleTextAttributes = [.font: UIFont(name: "Rubik-Medium", size: 17)!]
        if execise?.typeId == 12 {
            navigationItem.rightBarButtonItem = self.editButton
        } else {
            navigationItem.rightBarButtonItem = nil
        }
        tableView.reloadData()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        guard let cell = tableView.cellForRow(at: IndexPath(row: 1, section: 0)) as? ImagesTableViewCell else {return}
        cell.loadScrollView(fake: false)
    }
    
    @IBAction func back(_ sender: Any) {
        navigationController?.popViewController(animated: true)
    }
    @IBAction func editExercise(_ sender: Any) {
        let destinationVC = self.storyboard?.instantiateViewController(withIdentifier: "NewExerciseViewController") as! NewExerciseViewController
        let manager = NewExerciseManager.shared
        manager.dataSource.editMode = true
        manager.dataSource.newExerciseModel = execise ?? Exercise()
        var pictures = [Data]()
        if let images = execise?.pictures {
            for image in images {
                if let url = URL(string: image.url) {
                    if let data = try? Data(contentsOf: url) {
                        pictures.append(data)
                    }
                }
            }
        }
        manager.dataSource.pictures = pictures
        destinationVC.exercManager = manager
        let navigationController = UINavigationController(rootViewController: destinationVC)
        self.present(navigationController, animated: true, completion: nil)
    }
    
    func playVideo(url: String) {
        if let VideoURL = URL(string: url) {
            let player = AVPlayer(url: VideoURL)
            let playerViewController = AVPlayerViewController()
            playerViewController.player = player
            self.present(playerViewController, animated: true) {
                playerViewController.player!.play()
            }
        }
    }
}

extension ExercisesInfoViewController: UITableViewDataSource, UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 6
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch indexPath.row {
        case 0: return configureNameCell(indexPath: indexPath)
        case 1: return configureImagesCell(indexPath: indexPath)
        case 2: return configureVideoCell(indexPath: indexPath)
        case 3: return configureFirstDescrCell(indexPath: indexPath)
        case 4: return configureSecondDescrCell(indexPath: indexPath)
        case 5: return configureThirdDescrCell(indexPath: indexPath)
        default: return UITableViewCell()
        }
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        switch indexPath.row {
            case 1: return 250
            case 2: return 50
            default: return UITableViewAutomaticDimension
        }
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.row == 2 {
            if let video = execise?.videoUrl {
                playVideo(url: video)
            }
        }
        tableView.deselectRow(at: indexPath, animated: true)
    }
    
    func configureFirstDescrCell(indexPath: IndexPath) -> UITableViewCell {
        let fistDescCell = self.tableView.dequeueReusableCell(withIdentifier: "TextViewTableViewCell", for: indexPath) as? TextViewTableViewCell
        fistDescCell?.headingLabel.text = "Общая инфа"
        fistDescCell?.infoTextView.text = execise?.exerciseDescriprion
        return fistDescCell!
    }
    func configureSecondDescrCell(indexPath: IndexPath) -> UITableViewCell {
        let second = self.tableView.dequeueReusableCell(withIdentifier: "TextViewTableViewCell", for: indexPath) as? TextViewTableViewCell
        second?.headingLabel.text = "Как выполнять:"
        second?.infoTextView.text = execise?.howToDo
        return second!
    }
    func configureThirdDescrCell(indexPath: IndexPath) -> UITableViewCell {
        let third = self.tableView.dequeueReusableCell(withIdentifier: "TextViewTableViewCell", for: indexPath) as? TextViewTableViewCell
        third?.headingLabel.text = "Источник"
        third?.infoTextView.text = execise?.link
        return third!
    }
    func configureVideoCell(indexPath: IndexPath) -> UITableViewCell {
        let videoCell = self.tableView.dequeueReusableCell(withIdentifier: "PlayVideoTableViewCell", for: indexPath) as? PlayVideoTableViewCell
        return videoCell!
    }
    func configureNameCell(indexPath: IndexPath) -> UITableViewCell {
        let nameCell = self.tableView.dequeueReusableCell(withIdentifier: "TextTableViewCell", for: indexPath) as? TextTableViewCell
        nameCell?.namelabel.text = execise?.name ?? "No name"
        return nameCell!
    }
    func configureImagesCell(indexPath: IndexPath) -> UITableViewCell {
        let imageCell = self.tableView.dequeueReusableCell(withIdentifier: "ImagesTableViewCell", for: indexPath) as? ImagesTableViewCell
        guard let pictures = execise?.pictures else { return imageCell! }
        imageCell?.images = Array(pictures)
        return imageCell!
    }
    
}
