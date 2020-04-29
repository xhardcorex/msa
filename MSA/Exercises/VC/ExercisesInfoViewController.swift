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
import Firebase

class ExercisesInfoViewController: UIViewController {
  
  @IBOutlet weak var tableView: UITableView!
  @IBOutlet weak var editButton: UIBarButtonItem!
  
  var execise: Exercise? = nil
  var presenter: ExersisesTypesPresenter?
  var timer: Timer?
  var seconds = 0
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
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
    hideableNavigationBar(false)
    
    execise = RealmManager.shared.getArray(ofType: Exercise.self, filterWith: NSPredicate(format: "id = %@", execise?.id ?? "")).first
    let attrs = [NSAttributedString.Key.foregroundColor: darkCyanGreen,
                 NSAttributedString.Key.font: UIFont(name: "Rubik-Medium", size: 17)!]
    self.navigationController?.navigationBar.titleTextAttributes = attrs
    if execise?.typeId == 12 {
      navigationItem.rightBarButtonItem = self.editButton
    } else {
      navigationItem.rightBarButtonItem = nil
    }
    tableView.reloadData()
    startTimer()
  }
  
  override func viewDidAppear(_ animated: Bool) {
    hideableNavigationBar(true)
    guard let cell = tableView.cellForRow(at: IndexPath(row: 1, section: 0)) as? ImagesTableViewCell else {return}
    cell.loadScrollView(fake: false)
  }
  
  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(true)
    stopTimer()
  }
  
  private func hideableNavigationBar(_ hide: Bool) {
    if #available(iOS 11.0, *) {
      navigationItem.hidesSearchBarWhenScrolling = hide
    }
  }
  
  @IBAction func back(_ sender: Any) {
    navigationController?.popViewController(animated: true)
  }
  @IBAction func editExercise(_ sender: Any) {
    let vc = self.storyboard?.instantiateViewController(withIdentifier: "NewExerciseViewController") as! NewExerciseViewController
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
    vc.exercManager = manager
    vc.presenter = self.presenter
    vc.presentedVC = self.self
    //let navigationController = UINavigationController(rootViewController: vc)
    navigationController?.pushViewController(vc, animated: true)
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
  
  func startTimer() {
    timer = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(fireTimer), userInfo: nil, repeats: true)
  }
  
  @objc func fireTimer() {
    seconds += 1
    if seconds > 15 {
      stopTimer()
      Analytics.logEvent("screen_exercise_description", parameters: nil)
    }
  }
  
  func stopTimer() {
    timer!.invalidate()
  }
  
}

extension ExercisesInfoViewController: UITableViewDataSource, UITableViewDelegate {
  
  func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    if let link = execise?.link, link == "" {
      return 6
    } else if execise?.typeId == 12 {
      return 5
    }
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
      case 2:
        if execise?.videoUrl == "" && execise?.link == ""{
          return 0
        } else {
          return 50
      }
      default: return UITableView.automaticDimension
    }
  }
  
  func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    if indexPath.row == 2 {
      if let video = execise?.link.youtubeID {
        let storyBoard = UIStoryboard(name: "Exercises", bundle:nil)
        let vc = storyBoard.instantiateViewController(withIdentifier: "YoutubePlayerViewController") as! YoutubePlayerViewController
        vc.youtubeID = video
        self.present(vc, animated: true, completion: nil)
      } else if let video = execise?.videoUrl {
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
    if execise?.videoUrl == "" && execise?.link == ""{
      videoCell?.icon.isHidden = true
      videoCell?.textLab.isHidden = true
    } else {
      videoCell?.icon.isHidden = false
      videoCell?.textLab.isHidden = false
    }
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
