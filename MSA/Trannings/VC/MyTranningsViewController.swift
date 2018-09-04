//
//  MyTranningsViewController.swift
//  MSA
//
//  Created by Pavlo Kharambura on 6/10/18.
//  Copyright © 2018 Pavlo Kharambura. All rights reserved.
//

import UIKit
import FZAccordionTableView
import SDWebImage

class MyTranningsViewController: UIViewController {

    @IBOutlet weak var loadingView: UIView!
    
    @IBOutlet weak var tableView: FZAccordionTableView!
    @IBOutlet weak var weekLabel: UILabel!
    @IBOutlet weak var segmentControl: UISegmentedControl!
    
    let manager = TrainingManager()
    var weekNumber = 0

    override func viewDidLoad() {
        super.viewDidLoad()

        initialViewConfiguration()
        initialDataLoading()
        
    }

    override func viewWillAppear(_ animated: Bool) {
        tableView.reloadData()
    }
    
    private func initialDataLoading() {
        manager.initDataSource(dataSource: TrainingsDataSource.shared)
        manager.initView(view: self)
        manager.loadTrainingsFromRealm()
        manager.syncUnsyncedTrainings()
    }
    
     private func initialViewConfiguration() {
        loadingView.isHidden = true
        segmentControl.layer.masksToBounds = true
        segmentControl.layer.cornerRadius = 13
        segmentControl.layer.borderColor = lightBlue.cgColor
        segmentControl.layer.borderWidth = 1
        navigationController?.navigationBar.layer.backgroundColor = UIColor(red: 249/255, green: 249/255, blue: 249/255, alpha: 1).cgColor
        navigationController?.setNavigationBarHidden(false, animated: true)
        let attrs = [NSAttributedStringKey.foregroundColor: UIColor.black,
                     NSAttributedStringKey.font: UIFont(name: "Rubik-Medium", size: 17)!]
        self.navigationController?.navigationBar.titleTextAttributes = attrs
        segmentControl.setTitleTextAttributes([NSAttributedStringKey.font: UIFont(name: "Rubik-Medium", size: 13)!],for: .normal)
        configureTableView()
    }
    
    private func configureTableView() {
        tableView.delegate = self
        tableView.dataSource = self
        tableView.showsVerticalScrollIndicator = false
        self.tableView.tableFooterView = UIView()
        tableView.allowMultipleSectionsOpen = true
        tableView.register(UINib(nibName: "TrainingDayHeaderView", bundle: nil), forHeaderFooterViewReuseIdentifier: "TrainingDayHeaderView")
        tableView.register(UINib(nibName: "ExerciseTableViewCell", bundle: nil), forCellReuseIdentifier: "ExerciseTableViewCell")
        tableView.register(UINib(nibName: "AddExerciseToDayTableViewCell", bundle: nil), forCellReuseIdentifier: "AddExerciseToDayTableViewCell")
    }
    
    @IBAction func back(_ sender: Any) {
        navigationController?.popViewController(animated: true)
    }
    @IBAction func optionsButton(_ sender: Any) {
        showOptionsAlert(addDayWeek: false)
    }
    @IBAction func showCalendar(_ sender: Any) {
        self.performSegue(withIdentifier: "showCalendar", sender: nil)
    }
    @IBAction func saveTemplate(_ sender: Any) {
        showOptionsAlert(addDayWeek: true)
    }
    @IBAction func previousWeek(_ sender: Any) {
        if weekNumber != 0 {
            weekNumber -= 1
            changeWeek(plus: false)
        }
    }
    @IBAction func nextWeek(_ sender: Any) {
        guard let weekCount = manager.getCurrentTraining()?.weeks.count else {return}
        if weekCount != 0 && weekNumber != weekCount - 1 {
            weekNumber += 1
            changeWeek(plus: true)
        }
    }
    
    func showAddDayWeekAlert() {
        let alert = UIAlertController(title: "Редактирование тренировки", message: "", preferredStyle: UIAlertControllerStyle.alert)
        
        let myString  = "Редактирование тренировки"
        var myMutableString = NSMutableAttributedString()
        myMutableString = NSMutableAttributedString(string: myString as String, attributes: [NSAttributedStringKey.font: UIFont(name: "Rubik-Medium", size: 17)!])
        myMutableString.addAttribute(NSAttributedStringKey.foregroundColor, value: UIColor.black, range: NSRange(location:0,length:myString.count))
        alert.setValue(myMutableString, forKey: "attributedTitle")
    }

    func saveTemplate() {
        manager.setCurrent(training: manager.getTrainings()?.first)
        manager.dataSource?.newTemplate = TrainingTemplate()
        self.performSegue(withIdentifier: "createTemplate", sender: nil)
    }
    
    func deleteTraining() {
        manager.deleteTraining(with: "\(manager.dataSource?.currentTraining?.id ?? -1)")
    }
    
    func showOptionsAlert(addDayWeek: Bool) {
        let alert = UIAlertController(title: "Редактирование тренировки", message: "", preferredStyle: UIAlertControllerStyle.alert)
        
        let myString  = "Редактирование тренировки"
        var myMutableString = NSMutableAttributedString()
        myMutableString = NSMutableAttributedString(string: myString as String, attributes: [NSAttributedStringKey.font: UIFont(name: "Rubik-Medium", size: 17)!])
        myMutableString.addAttribute(NSAttributedStringKey.foregroundColor, value: UIColor.black, range: NSRange(location:0,length:myString.count))
        alert.setValue(myMutableString, forKey: "attributedTitle")
        
        let firstAction = UIAlertAction(title: "Сохранить как шаблон", style: .default, handler: { action in
            self.segmentControl.layer.borderColor = lightBlue.cgColor
            if addDayWeek {
                self.addWeek()
            } else {
                self.saveTemplate()
            }
        })
        let secondAction = UIAlertAction(title: "Удалить тренировку", style: .default, handler: { action in
            self.segmentControl.layer.borderColor = lightBlue.cgColor
            if addDayWeek {
                self.addDay()
            } else {
                self.deleteTraining()
            }
        })
        let cancel = UIAlertAction(title: "Отмена", style: .default, handler: { action in
            self.segmentControl.layer.borderColor = lightBlue.cgColor
        })
        
        alert.addAction(firstAction)
        alert.addAction(secondAction)
        alert.addAction(cancel)
        segmentControl.layer.borderColor = UIColor.lightGray.cgColor
        self.present(alert, animated: true, completion: nil)
        if addDayWeek {
            setFont(action: firstAction, text: "Добавить неделю", regular: true)
            setFont(action: secondAction, text: "Добавить день", regular: true)
        } else {
            setFont(action: firstAction, text: "Сохранить как шаблон", regular: true)
            setFont(action: secondAction, text: "Удалить тренировку", regular: true)
        }
        setFont(action: cancel, text: "Отмена", regular: false)
    }

    private func setFont(action: UIAlertAction,text: String, regular: Bool) {
        var fontName = "Rubik"
        if !regular {
            fontName = "Rubik-Medium"
        }
        let attributedText = NSMutableAttributedString(string: text)
        let range = NSRange(location: 0, length: attributedText.length)
        attributedText.addAttribute(kCTFontAttributeName as NSAttributedStringKey, value: UIFont(name: fontName, size: 17.0)!, range: range)
        guard let label = (action.value(forKey: "__representer") as AnyObject).value(forKey: "label") as? UILabel else { return }
        label.attributedText = attributedText
    }
    
    func addDay() {
        guard let week = manager.dataSource?.currentWeek else {
            AlertDialog.showAlert("Нельзя добавить день!", message: "Сначала добавьте неделю", viewController: self)
            return
        }
        try! manager.realm.performWrite {
            let newDay = TrainingDay()
            newDay.id = newDay.incrementID()
            week.days.append(newDay)
            self.manager.editTraining(wiht: self.manager.getCurrentTraining()?.id ?? -1, success: {})
        }
    }
    func addWeek() {
        guard let training = manager.dataSource?.currentTraining else {return}
        try! manager.realm.performWrite {
            let newWeek = TrainingWeek()
            newWeek.id = newWeek.incrementID()
            let newDay = TrainingDay()
            newDay.id = newDay.incrementID()
            newWeek.days.append(newDay)
            training.weeks.append(newWeek)
            self.manager.editTraining(wiht: training.id, success: {})
        }
    }
    
    @objc
    private func startTraining(sender: UIButton) {
        
    }
    
    @objc
    private func changeDate(sender: UIButton) {
        manager.setCurrent(day: manager.dataSource?.currentWeek?.days[sender.tag])
        datePickerTapped()
    }
    
    func datePickerTapped() {
        DatePickerDialog(buttonColor: lightBlue_).show("Выберите дату", doneButtonTitle: "Выбрать", cancelButtonTitle: "Отменить", datePickerMode: .date) {
            (date) -> Void in
            if let dt = date {
                let formatter = DateFormatter()
                formatter.dateFormat = "dd.MM.yyyy"
                try! self.manager.realm.performWrite {
                    self.manager.dataSource?.currentDay?.date = formatter.string(from: dt)
                    self.manager.editTraining(wiht: self.manager.getCurrentTraining()?.id ?? -1, success: {})
                }
            }
        }
    }
    
    @objc
    private func startRoundTraining(sender: UIButton) {
        manager.setCurrent(day: manager.dataSource?.currentWeek?.days[sender.tag])
        self.performSegue(withIdentifier: "roundTraining", sender: nil)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        switch segue.identifier {
        case "showExerciseInTraining":
            guard let vc = segue.destination as? IterationsViewController else {return}
            vc.manager = self.manager
        case "showCalendar":
            guard let vc = segue.destination as? CalendarViewController else {return}
            vc.manager = self.manager
        case "createTemplate":
            guard let vc = segue.destination as? CreateTemplateViewController else {return}
            vc.manager = self.manager
        case "roundTraining":
            guard let vc = segue.destination as? CircleTrainingDayViewController else {return}
            vc.manager = self.manager
        case "addExercise":
            guard let vc = segue.destination as? ExercisesViewController else {return}
            vc.trainingManager = self.manager
        default:
            return
        }
    }
    
    func changeWeek(plus: Bool) {
        manager.dataSource?.currentWeek = manager.dataSource?.currentTraining?.weeks[weekNumber]
        weekLabel.text = "Неделя #\(weekNumber+1)"
        if plus {
            UIView.transition(with: self.tableView, duration: 0.35, options: .transitionCrossDissolve, animations: { self.tableView.reloadData() })
        } else {
            UIView.transition(with: self.tableView, duration: 0.35, options: .transitionCrossDissolve, animations: { self.tableView.reloadData() })
        }
    }
}

extension MyTranningsViewController: UITableViewDelegate, UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard let headerView = tableView.dequeueReusableHeaderFooterView(withIdentifier: "TrainingDayHeaderView") as? TrainingDayHeaderView else {return nil}
        
        if let day = manager.dataSource?.currentWeek?.days[section] {
            headerView.dateLabel.text = day.date == "" ? "______" : day.date
            headerView.dayLabel.text = "День #\(section + 1)"
//            headerView.nameLabel.text = day.name == "" ? "______" : day.name
            headerView.nameTextField.text = day.name == "" ? "______" : day.name
            headerView.nameTextField.tag = section
            headerView.nameTextField.delegate = self
        }
        headerView.sircleTrainingButton.tag = section
        headerView.startTrainingButton.tag = section
        headerView.changeDateButton.tag = section
        headerView.changeDateButton.addTarget(self, action: #selector(changeDate(sender:)), for: .touchUpInside)
        headerView.startTrainingButton.addTarget(self, action: #selector(startTraining(sender:)), for: .touchUpInside)
        headerView.sircleTrainingButton.addTarget(self, action: #selector(startRoundTraining(sender:)), for: .touchUpInside)

        return headerView
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 85
        
    }
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 60
    }
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.row == (manager.dataSource?.currentWeek?.days[indexPath.section].exercises.count ?? 0) {
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "AddExerciseToDayTableViewCell", for: indexPath) as? AddExerciseToDayTableViewCell else {return UITableViewCell()}
            return cell
        } else {
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "ExerciseTableViewCell", for: indexPath) as? ExerciseTableViewCell else {return UITableViewCell()}
            if let exercise = manager.dataSource?.currentWeek?.days[indexPath.section].exercises[indexPath.row] {
                if let ex = manager.realm.getElement(ofType: Exercise.self, filterWith: NSPredicate(format: "id = %d", exercise.exerciseId)) {
                    cell.exerciseNameLable.text = ex.name
                    cell.exerciseImageView.sd_setImage(with: URL(string: ex.pictures.first?.url ?? ""), placeholderImage: nil, options: .allowInvalidSSLCertificates, completed: nil)
                }
            }
            return cell
        }
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return (manager.dataSource?.currentWeek?.days[section].exercises.count ?? 0) + 1
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return manager.dataSource?.currentWeek?.days.count ?? 0
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let day = manager.dataSource?.currentWeek?.days[indexPath.section] else {return}
        manager.setCurrent(day: day)
        if indexPath.row != manager.dataSource?.currentWeek?.days[indexPath.section].exercises.count {
            guard let ex = manager.dataSource?.currentWeek?.days[indexPath.section].exercises[indexPath.row] else {return}
            manager.setCurrent(exercise: ex)
            self.performSegue(withIdentifier: "showExerciseInTraining", sender: nil)
        } else {
            self.performSegue(withIdentifier: "addExercise", sender: nil)
        }
    }
    
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }
    
    func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        let delete = getDeleteAction()
        return [delete]
    }
    
    private func getDeleteAction() -> UITableViewRowAction {
        let delete = UITableViewRowAction(style: .destructive, title: "Удалить") { (action, indexPath) in
            guard let object = self.manager.dataSource?.currentWeek?.days[indexPath.section].exercises[indexPath.row] else {return}
            self.manager.realm.deleteObject(object)
            self.manager.editTraining(wiht: self.manager.getCurrentTraining()?.id ?? -1, success: {})
            UIView.transition(with: self.tableView, duration: 0.35, options: .transitionCrossDissolve, animations: { self.tableView.reloadData() })
        }

        return delete
    }
    
}

extension MyTranningsViewController: FZAccordionTableViewDelegate {
    func tableView(_ tableView: FZAccordionTableView, willOpenSection section: Int, withHeader header: UITableViewHeaderFooterView?) {
        guard let sectionHeader = header as? TrainingDayHeaderView else { return }
        sectionHeader.headerState.toggle()
    }
    func tableView(_ tableView: FZAccordionTableView, willCloseSection section: Int, withHeader header: UITableViewHeaderFooterView?) {
        guard let sectionHeader = header as? TrainingDayHeaderView else { return }
        sectionHeader.headerState.toggle()
    }
}

extension MyTranningsViewController: TrainingsViewDelegate {
    
    func synced() {
        manager.loadTrainings()
    }

    func trainingEdited() {
        self.tableView.reloadData()
    }
    
    func templatesLoaded() {}
    
    func templateCreated() {}
    
    func startLoading() {
        loadingView.isHidden = false
    }
    
    func finishLoading() {
        loadingView.isHidden = true
    }
    
    func trainingsLoaded() {
        changeWeek(plus: true)
        manager.loadTemplates()
    }
    
    func errorOccurred(err: String) {
        print("Error")
    }
}

extension MyTranningsViewController: UITextFieldDelegate {
    func textFieldDidEndEditing(_ textField: UITextField) {
        try! manager.realm.performWrite {
            guard let object = manager.dataSource?.currentWeek?.days[textField.tag] else {return}
            object.name = textField.text ?? ""
            self.manager.editTraining(wiht: manager.getCurrentTraining()?.id ?? -1, success: {})
        }
    }
}