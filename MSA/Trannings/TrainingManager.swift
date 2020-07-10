//
//  TrainingManager.swift
//  MSA
//
//  Created by Pavlo Kharambura on 8/30/18.
//  Copyright © 2018 Pavlo Kharambura. All rights reserved.
//

import Foundation
import RealmSwift
import Firebase
import AVFoundation
import Firebase

@objc protocol TrainingsViewDelegate: class {
    func startLoading()
    func finishLoading()
    func trainingsLoaded()
    func templateCreated()
    func templatesLoaded()
    func trainingEdited()
    @objc optional func trainingDeleted()
    func errorOccurred(err: String)
    func synced()
}

protocol TrainingFlowDelegate: class {
    func changeTime(time: String, iterationState: IterationState, i: (Int,Int), stop: Bool)
    func higlightIteration(on: Int)
    func rewriteIterations()
}

enum TrainingState {
    case normal
    case round
    case iterationsOnly
}
enum IterationState {
    case work
    case rest
}

enum TrainingType {
    case my
    case notMine(userId: String?)
}

class TrainingManager {
    
    let realm = RealmManager.shared
    var dataSource: TrainingsDataSource? = TrainingsDataSource.shared
    var dataSourceCopy = TrainingsDataSource()
    private weak var view: TrainingsViewDelegate?
    private weak var flowView: TrainingFlowDelegate?
    
    var trainingType: TrainingType
    var firstLoad = true
    var sportsmanId: String? {
        switch trainingType {
        case .my:
            return AuthModule.currUser.id
        case .notMine(let id):
            return id
        }
    }
    
    func isMyProfile() -> Bool {
        return sportsmanId == AuthModule.currUser.id
    }
    
    init(type: TrainingType) {
        self.trainingType = type
    }
    
    func initDataSource(dataSource: TrainingsDataSource) {
        self.dataSource = dataSource
    }
    
    func initView(view: TrainingsViewDelegate) {
        self.view = view
    }
    func initFlowView(view: TrainingFlowDelegate) {
        self.flowView = view
    }
    
    func synchronizeTrainingsData(success: (() -> Void)?, failture: (() -> Void)? = nil) {
        let dispatchGroup = DispatchGroup()
        
        if !InternetReachability.isConnectedToNetwork() {
            failture?()
        } else {
            dispatchGroup.enter()
            loadTrainings(success: {
                dispatchGroup.leave()
            })
            
            dispatchGroup.enter()
            getMyExercises(success: {
                dispatchGroup.leave()
            })
            
            dispatchGroup.notify(queue: .main) {
                success?()
            }
        }
    }
    
    func getExercisesOf(day: Int) -> [ExerciseInTraining] {
        return Array(dataSource?.currentWeek?.days[day].exercises ?? List<ExerciseInTraining>())
    }
  
    func insertNewWeek() {
            do {
                try realm.performWrite {
                    guard let week = CopyTrainingsManager.shared.copiedWeek else {return}
                    let newWeek = TrainingWeek()
                    newWeek.id = newWeek.incrementID()
                    newWeek.name = ""
                    let days = List<TrainingDay>()
                    for (index,day) in week.days.enumerated() {
                        let newDay = makeDayCopy(of: day)
                        newDay.id += index + 100
                        newDay.date = ""
                        days.append(newDay)
                    }
                    newWeek.days = days
                    dataSource?.currentTraining?.wasSync = false
                  if let index = dataSource?.currentTraining?.weeks.index(of: dataSource!.currentWeek!) {
                    dataSource?.currentTraining?.weeks[index] = newWeek
                  }
                    
                }
            } catch {
                print(error)
            }
            self.editTraining(wiht: getCurrentTraining()?.id ?? -1, success: {})
            CopyTrainingsManager.shared.copiedWeek = nil
        }
    
    func copyWeek() {
        do {
            try realm.performWrite {
                guard let week = dataSource?.currentWeek else {return}
                let newWeek = TrainingWeek()
                newWeek.id = newWeek.incrementID()
                newWeek.name = ""
                let days = List<TrainingDay>()
                for (index,day) in week.days.enumerated() {
                    let newDay = makeDayCopy(of: day)
                    newDay.id += index + 100
                    newDay.date = ""
//                  newDay.exercises.forEach({$0.iterations.forEach({})})
                    days.append(newDay)
                }
                newWeek.days = days
                dataSource?.currentTraining?.wasSync = false
                dataSource?.currentTraining?.weeks.append(newWeek)
            }
        } catch {
            print(error)
        }
        self.editTraining(wiht: getCurrentTraining()?.id ?? -1, success: {})
    }
    
  
    func insertNewDay() {
        do {
            try realm.performWrite {
              let newDay = makeDayCopy(of: CopyTrainingsManager.shared.copiedDay!)
              newDay.date = ""
              dataSource?.currentWeek?.wasSync = false
              dataSource?.currentWeek?.days.insert(newDay, at: (dataSource?.currentWeek?.days.count)!)
            }
        } catch {
            print(error)
        }
        self.editTraining(wiht: getCurrentTraining()?.id ?? -1, success: {})
        CopyTrainingsManager.shared.copiedDay = nil
    }
  
    func copyDay(at: Int) {
        do {
            try realm.performWrite {
                if let day = dataSource?.currentWeek?.days[at] {
                    let newDay = makeDayCopy(of: day)
                    newDay.date = ""
                    dataSource?.currentWeek?.wasSync = false
                    dataSource?.currentWeek?.days.insert(newDay, at: at+1)
                }
            }
        } catch {
            print(error)
        }
        self.editTraining(wiht: getCurrentTraining()?.id ?? -1, success: {})
    }
    
    private func makeDayCopy(of day: TrainingDay) -> TrainingDay {
        let newDay = TrainingDay()
        newDay.id = day.incrementID()
        newDay.date = day.date
        newDay.name = day.name
        newDay.roundExercisesIds = day.roundExercisesIds
        
        let exercises = List<ExerciseInTraining>()
        for exe in day.exercises {
            
            let newExercise = ExerciseInTraining()
            newExercise.id = UUID().uuidString
            newExercise.byTrainer = exe.byTrainer
            newExercise.exerciseId = exe.exerciseId
            newExercise.name = exe.name

            let iterations = List<Iteration>()
            for iter in exe.iterations {
                
                let newIteration = Iteration()
                newIteration.id = UUID().uuidString
                newIteration.counts = iter.counts
                newIteration.exerciseInTrainingId = iter.exerciseInTrainingId
                newIteration.restTime = iter.restTime
                newIteration.startTimerOnZero = iter.startTimerOnZero
                newIteration.weight = iter.weight
                newIteration.workTime = iter.workTime
                
                iterations.append(newIteration)
            }
            newExercise.iterations = iterations
            exercises.append(newExercise)
        }
        
        newDay.exercises = exercises
        
        return newDay
    }
    
    func replaceExercises(of day: Int, from index: Int, to day_: Int, at index_: Int) {
        do {
            try realm.performWrite {
                if let replacementExercise = dataSource?.currentWeek?.days[day].exercises[index] {
                    dataSource?.currentWeek?.wasSync = false
                    dataSource?.currentWeek?.days[day].exercises.remove(at: index)
                    if dataSource?.currentWeek?.days.count == day_ {
                        if dataSource?.currentWeek?.days[day_-1].exercises.count == index_ - 1 {
                            dataSource?.currentWeek?.days[day_-1].exercises.insert(replacementExercise, at: (dataSource?.currentWeek?.days[day_-1].exercises.count)! - 1)
                        } else {
                            dataSource?.currentWeek?.days[day_-1].exercises.insert(replacementExercise, at: (dataSource?.currentWeek?.days[day_-1].exercises.count)!)
                        }
                        dataSource?.currentWeek?.days[day_-1].roundExercisesIds.removeAll()
                    } else {
                        if dataSource?.currentWeek?.days[day_].exercises.count == index_ - 1 {
                            dataSource?.currentWeek?.days[day_].exercises.insert(replacementExercise, at: index_ - 1)
                        } else {
                            dataSource?.currentWeek?.days[day_].exercises.insert(replacementExercise, at: index_)
                        }
                        dataSource?.currentWeek?.days[day_].roundExercisesIds.removeAll()
                    }
                    dataSource?.currentWeek?.days[day].roundExercisesIds.removeAll()
                }
            }
        } catch {
            print(error)
        }
        self.editTraining(wiht: getCurrentTraining()?.id ?? -1, success: {})
    }
    
    func checkForRoundTraining(at source: IndexPath, to destination: IndexPath) -> Bool {
        var secondDay: TrainingDay?
        if dataSource?.currentWeek?.days.count == destination.section {
            secondDay = dataSource?.currentWeek?.days[destination.section - 1]
        } else {
            secondDay = dataSource?.currentWeek?.days[destination.section]
        }
        let firstDay = dataSource?.currentWeek?.days[source.section]
        return (!(firstDay?.roundExercisesIds.isEmpty ?? true) && !(firstDay?.roundExercisesIds.first?.id == "")) || (!(secondDay?.roundExercisesIds.isEmpty ?? true)  && !(firstDay?.roundExercisesIds.first?.id == ""))
    }
    
    func isEmptyExercise() -> (Bool,[Int]?) {
        var indexes = [Int]()
        guard let exercises = dataSource?.currentDay?.exercises else {return (false,nil)}
        for (index,ex) in exercises.enumerated() {
            if ex.iterations.count == 0 {
                indexes.append(index)
            }
        }
        if indexes.isEmpty {
            return (false,nil)
        } else {
            return (true,indexes)
        }
    }
    
    func getDaysCount() -> Int {
        return dataSource?.currentWeek?.days.count ?? 0
    }

    func getWeeksCount() -> Int {
        return dataSource?.currentTraining?.weeks.count ?? 0
    }
    
    func getTrainings() -> [Training]? {
        return dataSource?.trainings
    }
    
    func setCurrent(day: TrainingDay?) {
        dataSource?.currentDay = day
    }
    func getCurrentday() -> TrainingDay? {
        return dataSource?.currentDay
    }
    
    func setCurrent(training: Training?) {
        dataSource?.currentTraining = training
    }
    func getCurrentTraining() -> Training? {
        return realm.getElement(ofType: Training.self, filterWith: NSPredicate(format: "id = %d", dataSource?.currentTraining?.id ?? -1))
    }
    func setCurrent(exercise: ExerciseInTraining) {
        dataSource?.currentExerciseInDay = exercise
    }
    func getCurrentExercise() -> ExerciseInTraining? {
        return realm.getElement(ofType: ExerciseInTraining.self, filterWith: NSPredicate(format: "id = %@", dataSource?.currentExerciseInDay?.id ?? ""))
    }
    func setCurrent(iteration: Iteration) {
        dataSource?.currentIteration = iteration
    }
    func getCurrentIteration() -> Iteration? {
        return dataSource?.currentIteration
    }
    func getTrainingsFromRealm() -> [Training]? {
        return realm.getArray(ofType: Training.self)
    }
    func getTemplatesFromRealm() -> [TrainingTemplate]? {
        return realm.getArray(ofType: TrainingTemplate.self)
    }
    func getDay(by id: Int) -> TrainingDay? {
        return realm.getElement(ofType: TrainingDay.self, filterWith: NSPredicate(format: "id = %d", id))
    }
    func getWeek(by id: Int) -> TrainingWeek? {
        return realm.getElement(ofType: TrainingWeek.self, filterWith: NSPredicate(format: "id = %d", id))
    }
    func getExercise(by id: String) -> ExerciseInTraining? {
        return realm.getElement(ofType: ExerciseInTraining.self, filterWith: NSPredicate(format: "id = %@", id))
    }
    func getExercise(with id: String) -> Exercise? {
        return realm.getElement(ofType: Exercise.self, filterWith: NSPredicate(format: "id = %@", id))
    }
    func getIteration(by id: String) -> Iteration? {
        return realm.getElement(ofType: Iteration.self, filterWith: NSPredicate(format: "id = %@", id))
    }
    func getTemplatesby(trainer id: Int) -> [TrainingTemplate]? {
        return realm.getArray(ofType: TrainingTemplate.self, filterWith: NSPredicate(format: "trianerId = %d", id))
    }
    func saveTemplateToRealm(templates: [TrainingTemplate]) {
        realm.saveObjectsArray(templates)
    }
    func saveTrainingsToRealm(trainings: [Training]) {
        realm.saveObjectsArray(trainings)
    }
    func saveDaysToRealm(days: [TrainingDay]) {
        realm.saveObjectsArray(days)
    }
    func saveWeeksToRealm(weeks: [TrainingWeek]) {
        realm.saveObjectsArray(weeks)
    }
    func saveExersInTrainingToRealm(ex: [ExerciseInTraining]) {
        realm.saveObjectsArray(ex)
    }
    func saveIterationsToRealm(iterations: [Iteration]) {
        realm.saveObjectsArray(iterations)
    }
    
    func saveTemplate() {
        if let id = AuthModule.currUser.id {
            self.view?.startLoading()
            let index = dataSource?.newTemplate?.incrementID() ?? 0
            let newInfo = makeTemplateForFirebase(trainerId: id, edit: false)
            Database.database().reference().child("Templates").child(id).child("\(index)").setValue(newInfo) { (error, databaseFer) in
                self.view?.finishLoading()
                if error == nil {
                    guard let newTemplate = self.dataSource?.newTemplate else {return}
            
                    self.realm.saveObject(newTemplate, update: false)
                    self.view?.templateCreated()
                } else {
                    self.view?.errorOccurred(err: error?.localizedDescription ?? "Unknown error")
                }
            }
        }
    }
    
    func makeTemplateForFirebase(trainerId: String, edit: Bool) -> [String:Any] {
        var index = Int()
        if edit {
            index = dataSource?.newTemplate?.id ?? 0
        } else {
            index = dataSource?.newTemplate?.incrementID() ?? 0
        }
        dataSource?.newTemplate?.id = index
        return [
        "id": dataSource?.newTemplate?.id ?? 0,
        "name": dataSource?.newTemplate?.name ?? "",
        "trainerId": trainerId,
        "typeId": dataSource?.newTemplate?.typeId ?? -1,
        "days": dataSource?.newTemplate?.days ?? 0,
        "trainingId": dataSource?.newTemplate?.trainingId ?? -1
        ]
    }
    
    func editTraining(wiht id: Int, success: @escaping()->(), failure: ((Error?)->())? = nil) {
        if let userId = sportsmanId {
            
            var newInfo = makeTrainingForFirebase(id: id, or: true)
            if sportsmanId != AuthModule.currUser.id {
                newInfo["editByTrainer"] = true
            }
            Database.database().reference().child("Trainings").child(userId).child("\(id)").updateChildValues(newInfo) { (error, ref) in
                self.view?.finishLoading()
                self.view?.trainingEdited()
                if error == nil {
                    self.setSynced()
                    if let object = self.dataSource?.currentTraining {
                        self.realm.saveObject(object)
                    }
                    success()
                } else {
                    failure?(error)
                    self.view?.errorOccurred(err: error?.localizedDescription ?? "")
                }
            }
        }
    }
    
    func addIteration(completion: @escaping ()->()) {
        try! realm.performWrite {
            let newIteration = Iteration()
            newIteration.id = UUID().uuidString
            newIteration.exerciseInTrainingId = getCurrentExercise()?.id ?? UUID().uuidString
            getCurrentExercise()?.iterations.append(newIteration)
            getCurrentTraining()?.wasSync = false
            editTraining(wiht: getCurrentTraining()?.id ?? -1, success: {})
        }
        completion()
    }
    
    func copyIteration(index: Int, completion: @escaping ()->()) {
        if let iteration = getCurrentExercise()?.iterations[index] {
            let iterationCopy = Iteration(value: iteration)
            iterationCopy.id = UUID().uuidString
            
            realm.saveObject(iterationCopy)
            try! realm.performWrite {
                getCurrentTraining()?.wasSync = false
                getCurrentExercise()?.iterations.append(iterationCopy)
                editTraining(wiht: getCurrentTraining()?.id ?? -1, success: {})
            }
        completion()
        }
    }
    
    func setDayRoundExercises(with ids: [String]) {
        guard let day = dataSource?.currentDay else {return}
        guard let trainingId = dataSource?.currentTraining?.id else {return}

        try! realm.performWrite {
            let list = List<IdString>()
            for id in ids {
                let newid = IdString()
                newid.id = id
                list.append(newid)
            }
            day.roundExercisesIds.removeAll()
            day.roundExercisesIds.append(objectsIn: list)
            day.wasSync = false
        }
        self.editTraining(wiht: trainingId, success: {})

    }
  
    func addCoppiedDay(week: TrainingWeek) {
           try! realm.performWrite {
               let newDay = TrainingDay()
               newDay.id = newDay.incrementID()
               week.days.append(newDay)
           }
           self.editTraining(wiht: self.dataSource?.currentTraining?.id ?? -1, success: {})
       }
  
    func insertDay(day: TrainingDay, week: TrainingWeek) {
        try! realm.performWrite {
            let newDay = TrainingDay()
            newDay.id = newDay.incrementID()
            week.days.append(newDay)
        }
        self.editTraining(wiht: self.dataSource?.currentTraining?.id ?? -1, success: {})
      
    }
  
    func addDay(week: TrainingWeek) {
        try! realm.performWrite {
            let newDay = TrainingDay()
            newDay.id = newDay.incrementID()
            week.days.append(newDay)
        }
        self.editTraining(wiht: self.dataSource?.currentTraining?.id ?? -1, success: {})
    }
    
    func deleteDay(at: Int) {
        guard let week = dataSource?.currentWeek else {return}
        guard let trainingId = dataSource?.currentTraining?.id else {return}
        try! realm.performWrite {
            dataSource?.currentTraining?.wasSync = false
        }
        realm.deleteObject(week.days[at])
        self.editTraining(wiht: trainingId, success: {})
    }
    
    func deleteWeek(at: Int) {
        guard let week = dataSource?.currentWeek else {return}
        guard let trainingId = dataSource?.currentTraining?.id else {return}

        try! realm.performWrite {
            dataSource?.currentTraining?.wasSync = false
        }
        for day in week.days {
            realm.deleteObject(day)
        }
        
        realm.deleteObject(week)
        if let w = dataSource?.currentTraining?.weeks, w.count == 0 {
            dataSource?.currentWeek = nil
        } else {
            if at == 0 {
                dataSource?.currentWeek = dataSource?.currentTraining?.weeks.first
            } else if let week = dataSource?.currentTraining?.weeks[at-1] {
                dataSource?.currentWeek = week
            } else if let week_ = dataSource?.currentTraining?.weeks[at+1] {
                dataSource?.currentWeek = week_
            } else {
                dataSource?.currentWeek = nil
            }
        }
        self.editTraining(wiht: trainingId, success: {})
    }
    
    func createWeak(in training: Training) {
        try! realm.performWrite {
            let newWeek = TrainingWeek()
            newWeek.id = newWeek.incrementID()
            let newDay = TrainingDay()
            newDay.id = newDay.incrementID()
            newWeek.days.append(newDay)
            training.weeks.append(newWeek)
            dataSource?.currentTraining = training
            dataSource?.currentWeek = newWeek
            self.editTraining(wiht: training.id, success: {})
        }
    }
    
    func loadTrainings(success: (() -> Void)? = nil, failture: (([NSError]) -> Void)? = nil) {
        if let id = sportsmanId {
          Database.database().reference().child("Trainings").child(id).observe(.value) { (snapchot) in
                self.observeTrainings(snapchot: snapchot, success: {
                    success?()
                })
            }
        }
    }
    
    func getMyExercises(success: (() -> Void)?, failture: (([NSError]) -> Void)? = nil) {
        if let id = sportsmanId {
          Database.database().reference().child("ExercisesByTrainers").child(id).observe(.value) { (data) in
                let items = parseExercises(snapchot: data)
                let myExerc = MyExercises()
                myExerc.id = AuthModule.currUser.id ?? ""
                for item in items {
                    myExerc.myExercises.append(item)
                }
                DispatchQueue.main.async {
                    self.realm.saveObject(myExerc)
                    success?()
                }
            }
        }
    }
    
    func clearRealm() {
        let realm = try! Realm()
        let trainings = realm.objects(Training.self)
        try! realm.write {
            realm.delete(trainings)
        }
        dataSource?.clearDB()
    }
    
    func loadTrainingsFromRealm() {
        let trainings = Array(realm.getArray(ofType: Training.self))
        dataSource?.set(trainings: trainings)
        dataSource?.currentTraining = trainings.first
        UserDefaults.init(suiteName: "group.easyappsolutions.widget")?.set(getAllDates(), forKey: "dates")
        self.view?.trainingsLoaded()
    }
    
    func getAllDates() -> [String] {
        var array = [String]()
        if let weeks = dataSource?.currentTraining?.weeks {
            for week in weeks {
                let days = week.days
                for day in days {
                    array.append(day.date)
                }
            }
        }
        return array
    }
    
    func loadTemplates() {
        if let id = AuthModule.currUser.id {
//            self.view?.startLoading()
            Database.database().reference().child("Templates").child(id).observeSingleEvent(of: .value) { (snapchot) in
                self.observeTemplates(snapchot: snapchot)
            }
        }
    }
    
    func deleteTraining(with id: String) {
        if let userId = sportsmanId {
            self.view?.startLoading()
            Database.database().reference().child("Trainings").child(userId).child(id).removeValue { (error, ref) in
                self.view?.finishLoading()
                if error == nil {
                    guard let object = RealmManager.shared.getElement(ofType: Training.self, filterWith: NSPredicate(format: "id = %d", Int(id) ?? -1)) else {return}
                    
                    RealmManager.shared.deleteObject(object)
                    self.clearRealm()
                    self.view?.trainingDeleted!()
                } else {
                    self.view?.errorOccurred(err: error?.localizedDescription ?? "")
                }
            }
        }
    }
    
    func deleteTemplate(with id: String) {
        if let userId = AuthModule.currUser.id {
            self.view?.startLoading()
            Database.database().reference().child("Templates").child(userId).child(id).removeValue { (error, ref) in
                self.view?.finishLoading()
                if error == nil {
                    // DELETED
                } else {
                    self.view?.errorOccurred(err: error?.localizedDescription ?? "")
                }
            }
        }
    }
    
    func makeTrainingForFirebase(id: Int, or edit: Bool) -> [String:Any] {
        var newiterations = [[String:Any]]()
        var newexercises = [[String:Any]]()
        var newdays = [[String:Any]]()
        var newWeeks = [[String:Any]]()

        let training = dataSource?.currentTraining
        if let weeks = training?.weeks {
            newWeeks.removeAll()
            for week in weeks {
                newdays.removeAll()
                for day in week.days {
                    newexercises.removeAll()
                    for e in day.exercises {
                        newiterations.removeAll()
                        for i in e.iterations {
                            newiterations.append([
                                    "id": i.id,
                                    "exerciseInTrainingId": i.exerciseInTrainingId,
                                    "weight": i.weight,
                                    "counts": i.counts,
                                    "workTime": i.workTime,
                                    "restTime": i.restTime,
                                    "startTimerOnZero": i.startTimerOnZero ? 1 : 0
                                ])
                        }
                        newexercises.append([
                               "id": e.id,
                               "name": e.name.capitalizingFirstLetter(),
                               "exerciseId": e.exerciseId,
                               "iterations": newiterations
                            ])
                    }
                    newdays.append([
                           "id": day.id,
                           "name": day.name.capitalizingFirstLetter(),
                           "date": day.date,
                           "exercises": newexercises,
                           "idsForRound": day.roundExercisesIds.map{$0.id}.joined(separator: ", ")
                        ])
                }
                newWeeks.append([
                    "id": week.id,
                    "name": week.name,
                    "days": newdays
                    ])
            }
        }
        return [
            "id": dataSource?.currentTraining?.id ?? "",
            "name": (dataSource?.currentTraining?.name ?? "").capitalizingFirstLetter(),
            "trainerId": dataSource?.currentTraining?.trianerId ?? "",
            "userId": dataSource?.currentTraining?.userId ?? "",
            "weeks": newWeeks
        ]
    }
    
    func observeTemplates(snapchot: DataSnapshot) {
        self.view?.finishLoading()
        var items = [TrainingTemplate]()
        for snap in snapchot.children {
            let s = snap as! DataSnapshot
            if let _ = s.childSnapshot(forPath: "id").value as? NSNull {return}
            let template = TrainingTemplate()
            template.id = s.childSnapshot(forPath: "id").value as? Int ?? -1
            template.name = s.childSnapshot(forPath: "name").value as? String ?? ""
            template.trianerId = s.childSnapshot(forPath: "trainerId").value as? String ?? ""
            template.trainingId = s.childSnapshot(forPath: "trainingId").value as? Int ?? 0
            template.days = s.childSnapshot(forPath: "days").value as? Int ?? 0
            template.typeId = s.childSnapshot(forPath: "typeId").value as? Int ?? -1
            items.append(template)
        }
        self.dataSource?.templates = items
        self.saveTemplateToRealm(templates: items)
        self.view?.templatesLoaded()
    }
    
    func checkIfEditedByTrainer(callback: ((_ byTrainer: Bool,_ snap: DataSnapshot?)->())?) {
        if let id = sportsmanId {
            Database.database().reference().child("Trainings").child(id).observeSingleEvent(of: .value) { (snapchot) in
                for snap in snapchot.children {
                    let s = snap as! DataSnapshot
                    if let id = s.childSnapshot(forPath: "id").value as? Int, id != -1 {
                        if let isTrainer = (s.childSnapshot(forPath: "editByTrainer").value as? Int) {
                            callback?(isTrainer == 1 ? true : false, snapchot)
                        } else {
                            callback?(false, snapchot)
                        }
                    }
                }
            }
        }
    }
    
    func observeTrainings(snapchot: DataSnapshot, success: (() -> Void)? = nil) {
//        if sportsmanId != AuthModule.currUser.id {
//            self.view?.finishLoading()
//        }
        var items = [Training]()
        for snap in snapchot.children {
            let s = snap as! DataSnapshot
            if let _ = s.childSnapshot(forPath: "id").value as? NSNull {
                return
            }
            guard let _ = s.childSnapshot(forPath: "id").value as? Int else {
                continue
            }
            let training = Training()
            training.id = s.childSnapshot(forPath: "id").value as? Int ?? 0
            training.name = s.childSnapshot(forPath: "name").value as? String ?? ""
            training.trianerId = s.childSnapshot(forPath: "trainerId").value as? String ?? ""
            training.userId = s.childSnapshot(forPath: "userId").value as? Int ?? -1
            
            if let weeks = s.childSnapshot(forPath: "weeks").value as? NSArray {
                for w in (weeks as! [[String:Any]]) {
                    let week = TrainingWeek()
                    week.wasSync = true
                    week.id = w["id"] as? Int ?? -1
                    week.name = w["name"] as? String ?? ""
                    let daysInWeek = List<TrainingDay>()
                    if let days = w["days"] as? [[String:Any]] {
                        for d in days {
                            let day = TrainingDay()
                            day.wasSync = true
                            day.id = d["id"] as? Int ?? -1
                            day.name = d["name"] as? String ?? ""
                            day.date = d["date"] as? String ?? ""
                            if let exercIds = d["idsForRound"] as? String {
                                let array = List<IdString>()
                                let ids = exercIds.components(separatedBy: ", ")
                                for id_ in ids {
                                    let id = IdString()
                                    id.id = id_
                                    array.append(id)
                                }
                                day.roundExercisesIds.append(objectsIn: array)
                            }
                            let exercisesInDay = List<ExerciseInTraining>()
                            if let exercises = d["exercises"] as? [[String:Any]] {
                                for e in exercises {
                                    let exercise = ExerciseInTraining()
                                    exercise.wasSync = true
                                    exercise.id = e["id"] as? String ?? UUID().uuidString
                                    exercise.name = e["name"] as? String ?? ""
                                    exercise.exerciseId = e["exerciseId"] as? String ?? ""
                                    let exerciseIterations = List<Iteration>()
                                    if let iterations = e["iterations"] as? [[String:Any]] {
                                        for i in iterations {
                                            let iteration = Iteration()
                                            iteration.wasSync = true
                                            iteration.id = i["id"] as? String ?? UUID().uuidString
                                            iteration.exerciseInTrainingId = i["exerciseInTrainingId"] as? String ?? UUID().uuidString
                                            iteration.counts = i["counts"] as? Int ?? 0
                                            iteration.weight = i["weight"] as? Int ?? 0
                                            iteration.restTime = i["restTime"] as? Int ?? 0
                                            iteration.workTime = i["workTime"] as? Int ?? 0
                                            iteration.startTimerOnZero = (i["startTimerOnZero"] as? Int ?? 0) == 1 ? true : false
                                            exerciseIterations.append(iteration)
                                        }
                                    }
                                    exercise.iterations = exerciseIterations
                                    exercisesInDay.append(exercise)
                                }
                            }
                            day.exercises = exercisesInDay
                            daysInWeek.append(day)
                        }
                    }
                    week.days = daysInWeek
                    training.weeks.append(week)
                }
            }
            items.append(training)
        }
        if items.isEmpty {
            let objects = realm.getArray(ofType: Training.self)
            realm.deleteObjectsArray(objects)
        }
        dataSource?.set(trainings: items)
        dataSource?.currentTraining = items.first
        self.saveTrainingsToRealm(trainings: items)
        self.setSynced()
        firstLoad = false
        self.view?.trainingsLoaded()
        success?()
    }
    
    func syncUnsyncedTrainings() {
        let trainings = realm.getArray(ofType: Training.self)
        let weeks = realm.getArray(ofType: TrainingWeek.self)
        let days = realm.getArray(ofType: TrainingDay.self)
        let ex = realm.getArray(ofType: ExerciseInTraining.self)
        let iterations = realm.getArray(ofType: Iteration.self)
//, filterWith: NSPredicate(format: "wasSync = %@", NSNumber(booleanLiteral: false))
        
        if trainings.contains(where: {$0.wasSync == false && $0.id != -1}) || weeks.contains(where: {$0.wasSync == false && $0.id != -1}) || days.contains(where: {$0.wasSync == false && $0.id != -1}) || ex.contains(where: {$0.wasSync == false && $0.id != ""}) || iterations.contains(where: {$0.wasSync == false && $0.id != ""}) {
            
            self.checkIfEditedByTrainer { (edited, snap) in
                if edited, let s = snap {
                    self.observeTrainings(snapchot: s, success: {})
                    return
                } else {
                    let dispatch = DispatchGroup()
                    for training in trainings {
                        dispatch.enter()
                        if training.id == -1 {
                            dispatch.leave()
                        } else {
                            self.dataSource?.currentTraining = training
                            self.editTraining(wiht: training.id, success: {
                                dispatch.leave()
                            })
                        }
                    }
                    dispatch.notify(queue: .main) {
                        self.setSynced()
                        self.view?.synced()
                    }
                }
            }
        } else {
            loadTrainings()
            getMyExercises(success: nil)
        }
    }
    
    func setSynced() {
        try! self.realm.performWrite {
            let trainings = realm.getArray(ofType: Training.self)
            let weeks = realm.getArray(ofType: TrainingWeek.self)
            let days = realm.getArray(ofType: TrainingDay.self)
            let ex = realm.getArray(ofType: ExerciseInTraining.self)
            let iterations = realm.getArray(ofType: Iteration.self)
            
            for training in trainings {
                training.wasSync = true
            }
            for week in weeks {
                week.wasSync = true
            }
            for day in days {
                day.wasSync = true
            }
            for e in ex {
                e.wasSync = true
            }
            for i in iterations {
                i.wasSync = true
            }
        }
    }
    
    func setWeekFromDay(day: TrainingDay) -> (Int,Int) {
        if let weeks = getCurrentTraining()?.weeks {
            for (i,week) in weeks.enumerated() {
                if week.days.contains(day) {
                    dataSource?.currentWeek = week
                    return (i, week.days.firstIndex(where: {$0.id == day.id}) ?? 0)
                }
            }
        }
        return (0,0)
    }
    
    func getWeekNumber() -> Int {
        var i = 0
        if let weeks = getCurrentTraining()?.weeks {
            for week_ in weeks {
                if dataSource?.currentWeek?.id == week_.id {
                    return i
                } else {
                    i += 1
                }
            }
        }
        return i
    }
    
    func renameWeek(name: String?) {
        try! realm.performWrite {
            self.dataSource?.currentWeek?.name = name ?? ""
            self.dataSource?.currentWeek?.wasSync = false
        }
        guard let id = dataSource?.currentTraining?.id else {return}
        editTraining(wiht: id, success: {})
    }
    
    func numberOfDay() -> Int {
        guard let day = dataSource?.currentDay else {return 1}
        return (dataSource?.currentWeek?.days.index(of: day) ?? 0) + 1
    }
    func exercisesCount() -> Int {
        return getCurrentday()?.exercises.count ?? 0
    }
    
    // TRAINING FLOW
    
    private var timer = Timer()
    private var secondomer = Timer()
    
    private var iterationState: IterationState = .work
    var trainingState: TrainingState = .normal
    private var trainingStarted: Bool = false
    private var trainingInProgress: Bool = false
    private var secondomerStarted: Bool = false
    
    private var exercises: [ExerciseInTraining]? {
        didSet {
            iterationsCount = 0
            exercises?.forEach({iterationsCount += $0.iterations.count})
        }
    }
    private var currentExercise: ExerciseInTraining?
    private var iterations: [Iteration]?
    private var currentIteration: Iteration? {
        didSet {
            if isTrainingFinished() {
                fullStop()
            }
        }
        willSet {
            guard let id = currentIteration?.id else {
                return
            }
            trainedIterationsIDS.append(id)
        }
    }
    private var iterationsForTraining = [Iteration]()
    
    var trainedIterationsIDS: [String] = []
   
    private var iterationsCount: Int = 0
    var currentExerciseNumber = 0
    var currentIterationNumber = 0
    private var currentRestTime = 0
    private var currentWorkTime = 0
    private var secondomerTime = 0
    
    func isLastIteration() -> Bool {
        return trainedIterationsIDS.count >= iterationsForTraining.count
    }
    
    private func createIterationsCopy(i: Int) {
        self.iterationsForTraining = Array(dataSource?.currentExerciseInDay?.iterations ?? List<Iteration>())
        iterations = Array(dataSource?.currentExerciseInDay?.iterations ?? List<Iteration>())
        currentIteration = iterations?[i]
        setCurrentTime()
    }
    
    private func createDayExerciseCopy(exercise: Int, iteration: Int, success: @escaping ()-> ()) {
        exercises = Array(dataSource?.currentDay?.exercises ?? List<ExerciseInTraining>())
        if (exercises?.count ?? 0) > exercise {
            currentExercise = exercises?[exercise]
            iterations = Array(currentExercise?.iterations ?? List<Iteration>())
            if iterations?.count != 0 {
                currentIteration = iterations?[iteration]
                setCurrentTime()
                success()
            } else {
                currentExerciseNumber += 1
                nextStateOrIteration()
            }
        }
    }
    
    private func setCurrentTime() {
        currentWorkTime = currentIteration?.workTime ?? 0
        currentRestTime = currentIteration?.restTime ?? 0
        currentWorkTime = currentWorkTime == 0 ? currentWorkTime : currentWorkTime+1
        currentRestTime = currentRestTime == 0 ? currentRestTime : currentRestTime+1
    }
    
    func getIterationsCount() -> Int {
        return currentExercise?.iterations.count ?? 0
    }
    func getCurrentIterationInfo() -> Iteration {
        return currentIteration ?? Iteration()
    }
    
    private func nextIterationState() {
        switch iterationState {
        case .work: iterationState = .rest
        case .rest: iterationState = .work
        }
    }
    
    func checkForNotDoneIterations() -> Bool {
        for exercise in exercises! {
            if exercise.iterations.count > currentIterationNumber + 1 {
                return true
            }
        }
        return false
    }
    
    func iterationsSwitcher() {
        if currentIterationNumber == (iterations?.count ?? 0) - 1 {
            stopIteration()
            trainingStarted = false
            trainingInProgress = false
            switch trainingState {
                case .normal:
                    if (exercises?.count ?? 0) > currentExerciseNumber + 1 {
                        currentExerciseNumber += 1
                    } else {
                        fullStop()
                    }
                    currentIterationNumber = 0
                    startTraining()
                case .round:
                    roundFlow(withStart: true)
                case .iterationsOnly:
                    currentIterationNumber = 0
                    fullStop()
            }
        } else {
            switch trainingState {
                case .normal:
                    currentIterationNumber += 1
                case .round:
                    roundFlow(withStart: false)
                    currentExercise = exercises?[currentExerciseNumber]
                    iterations = Array(currentExercise?.iterations ?? List<Iteration>())
                case .iterationsOnly:
                    currentIterationNumber += 1
            }
            
            currentIteration = iterations?[currentIterationNumber]
            setCurrentTime()
        }
        if trainingState != .iterationsOnly {
            self.flowView?.higlightIteration(on: currentExerciseNumber)
        } else {
            self.flowView?.higlightIteration(on: currentIterationNumber)
        }
        
    }
    
    func isTrainingFinished() -> Bool {
        if trainingState == .iterationsOnly {
            return false
        } else {
            if let id = currentIteration?.id, trainedIterationsIDS.contains(id) {
                return true
            } else if trainedIterationsIDS.count == iterationsCount {
                return true
            }
            return false
        }
    }
    
    private func roundFlow(withStart: Bool) {
        let indexPath = getNext()
        if indexPath != nil {
            currentExerciseNumber = indexPath!.0
            currentIterationNumber = indexPath!.1
            if withStart {
                startTraining()
            }
        } else {
            fullStop()
        }
    }
    
//////////////////////// //////////////////////// //////////////////////// ////////////////////////
//////////////////////// //////////////////////// //////////////////////// ////////////////////////
// Preparing iterations
    
    func resetFromBackground(with time: Int) {
        guard let iteration = currentIteration else {
            return
        }
        switch iterationState {
        case .rest:
            if iteration.restTime == 0 {
                if iteration.startTimerOnZero {
                    currentRestTime += time
                }
            } else {
                if (currentRestTime - time) < 0 {
                    currentRestTime = 0
                } else {
                    currentRestTime -= time
                }
            }
            self.eventWithTimer(time: self.currentRestTime)
        case .work:
            if iteration.workTime == 0 {
                if iteration.startTimerOnZero {
                    currentWorkTime += time
                }
            } else {
                if (currentWorkTime - time) < 0 {
                    currentWorkTime = 0
                } else {
                    currentWorkTime -= time
                }
            }
            self.eventWithTimer(time: self.currentWorkTime)
        }
    }
    
    func setIterationsForNormal(completion: (() -> Void)? = nil) {
        exercises = Array(dataSource?.currentDay?.exercises ?? List<ExerciseInTraining>())
        iterationsForTraining.removeAll()
        if let exercises = exercises {
            for (index,_) in exercises.enumerated() {
                iterationsForTraining.append(contentsOf: Array(exercises[index].iterations))
            }
        }
        completion?()
    }
    
    func getIterationsAsNormal(at index: Int) {
        var iterations = [Iteration]()
        if let exercises = exercises {
            iterations = Array(exercises[index].iterations)
        }
        iterationsForTraining.append(contentsOf: iterations)
    }
    
    func setSpecialIterationsForRound(indexes: [Int], completion: @escaping ()->()) {
        exercises = Array(dataSource?.currentDay?.exercises ?? List<ExerciseInTraining>())
        iterationsForTraining.removeAll()
        
        var tempIndexes = [Int]()

        if let exercises = exercises {
            for (index, _) in exercises.enumerated() {
                if indexes.contains(index) {
                    tempIndexes.append(index)
                    if index == exercises.count-1 {
                        getIterationsAsRound(atEx: tempIndexes)
                    } else {
                        continue
                    }
                } else {
                    if !tempIndexes.isEmpty {
                        getIterationsAsRound(atEx: tempIndexes)
                        tempIndexes.removeAll()
                    }
                    getIterationsAsNormal(at: index)
                }
            }
        }
        completion()
    }

    func getIterationsAsRound(atEx indexes: [Int]) {
        var iterations = [Iteration]()
        var neededExercises = [ExerciseInTraining]()
        if let exercises = exercises {
            for (index, ex) in exercises.enumerated() {
                if indexes.contains(index) {
                    neededExercises.append(ex)
                }
            }
            iterations = prepareIterationsForRound(from: neededExercises)
        }
        iterationsForTraining.append(contentsOf: iterations)
    }
    
    func setIterationsForRound(completion: @escaping ()->()) {
        exercises = Array(dataSource?.currentDay?.exercises ?? List<ExerciseInTraining>())
        iterationsForTraining = prepareIterationsForRound(from: exercises!)
        completion()
    }
    
    func prepareIterationsForRound(from ex: [ExerciseInTraining]) -> [Iteration] {
        var array = [Iteration]()
        var len = 0
        for e in ex {
            if len < e.iterations.count {
                len = e.iterations.count
            }
        }
        for index in 1...len {
            for e in ex {
                if e.iterations.count >= index {
                    array.append(e.iterations[index-1])
                }
            }
        }
        return array
    }

//////////////////////// //////////////////////// //////////////////////// ////////////////////////
//////////////////////// //////////////////////// //////////////////////// ////////////////////////

    
    
    private func getNext() -> (Int,Int)? {
        var numInMainArray = 0
        var exersN = 0
        var iterN = 0
        
        for iteration in iterationsForTraining {
            let curIter = exercises?[currentExerciseNumber].iterations[currentIterationNumber]
            if iteration.id == curIter!.id {
                if numInMainArray == (iterationsForTraining.count - 1) {
                    return nil
                } else {
                    for ex in exercises ?? [] {
                        iterN = 0
                        for i in ex.iterations {
                            if i.id == iterationsForTraining[numInMainArray+1].id {
                                return (exersN, iterN)
                            }
                            iterN += 1
                        }
                        exersN += 1
                    }
                }
            } else {
                numInMainArray += 1
            }
        }
        return nil
    }
    
    private func startTimer() {
        Analytics.logEvent("start_timer", parameters: nil)
        trainingInProgress = true
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { (timer) in
            if !self.isTrainingFinished() {
                if let current = self.currentIteration {
                    if self.iterationState == .work {
                        if self.currentWorkTime >= 0 {
                            self.currentWorkTime -= 1
                            self.eventWithTimer(time: self.currentWorkTime)
                        } else {
                            if (current.startTimerOnZero) && current.workTime <= 0 {
                                self.stopIteration()
                                self.startSecondomer()
                            } else if !(current.startTimerOnZero) && current.workTime <= 0 {
                                self.stopIteration()
                                self.eventWithTimer(time: self.currentWorkTime)
                            } else {
                                self.nextIterationState()
                            }
                        }
                    } else {
                        if self.currentRestTime >= 0 {
                            self.currentRestTime -= 1
                            self.eventWithTimer(time: self.currentRestTime)
                        } else {
                            if (current.startTimerOnZero) && current.restTime <= 0 {
                                self.stopIteration()
                                self.iterationState = .rest
                                self.startSecondomer()
                            } else if !(current.startTimerOnZero) && current.restTime <= 0 {
                                self.stopIteration()
                                self.iterationState = .rest
                                self.eventWithTimer(time: self.currentRestTime)
                            } else {
                                self.nextIterationState()
                                self.iterationsSwitcher()
                            }
                        }
                    }
                }
            } else {
                self.fullStop()
                self.timer.invalidate()
                self.trainedIterationsIDS.removeAll()
            }
        }
    }
    
    private func startSecondomer() {
        secondomerStarted = true
        secondomer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { (timer) in
            self.secondomerTime += 1
            self.eventWithTimer(time: self.secondomerTime)
        }
        Analytics.logEvent("start_stopwatch", parameters: nil)
    }
    private func pauseSecondomer() {
        secondomer.invalidate()
    }
    private func stopSecondomer() {
        pauseSecondomer()
        secondomerStarted = false
        secondomerTime = 0
    }
    
    func setState(state: TrainingState)  {
        trainingState = state
    }
    
    func startExercise() {
        if trainingState == .iterationsOnly {
            createIterationsCopy(i: currentIterationNumber)
        } else {
            startTraining()
        }
        trainingStarted = true
        trainingInProgress = true
        startTimer()
        self.flowView?.higlightIteration(on: currentIterationNumber)
    }
    
    func finish() {
        trainingStarted = false
        trainingInProgress = false
        secondomerStarted = false
        currentIterationNumber = 0
        currentExerciseNumber = 0
        currentRestTime = 0
        currentWorkTime = 0
        secondomerTime = 0
    }

    func startTraining() {
        createDayExerciseCopy(exercise: currentExerciseNumber, iteration: currentIterationNumber, success: {
            self.trainingStarted = true
            self.trainingInProgress = true
            self.startTimer()
            self.flowView?.higlightIteration(on: self.currentExerciseNumber)
        })
    }
    
    func startExercise(from i: Int) {
        if trainingInProgress && trainingStarted {
            self.stopIteration()
            currentIterationNumber = 0
            trainingStarted = false
            trainingInProgress = false
        }
        currentIterationNumber = i
        startExercise()
    }
    
    func pauseIteration() {
        timer.invalidate()
        pauseSecondomer()
        trainingInProgress = false
        trainingStarted = true
    }
    
    func startOrContineIteration() {
        trainingInProgress = true
        if trainingStarted {
            if secondomerStarted {
                startSecondomer()
            } else {
                startTimer()
            }
        } else {
            if trainingState == .normal || trainingState == .round {
                startTraining()
            } else {
                startExercise()
            }
        }
    }

    func nextStateOrIteration() {
        saveIterationsInfo()
        if trainingStarted {
            nextIterationState()
            var time = Int()
            if iterationState == .work {
                self.iterationsSwitcher()
                time = currentWorkTime
            } else {
                time = currentRestTime
            }
            if secondomerStarted {
                stopSecondomer()
                startTimer()
            }
            if trainingInProgress {
                eventWithTimer(time: time)
                if !timer.isValid {
                    startTimer()
                }
            } else {
                eventWithTimer(time: 0)
                if trainingState == .normal {
                    startTraining()
                } else {
                    startExercise()
                }
            }
        }
        
    }
    
    func stopIteration() {
        timer.invalidate()
        stopSecondomer()
        iterationState = .work
    }
    
    func fullStop(back: Bool = true) {
        self.iterationsCount = 0
        if !back {
            self.flowView?.higlightIteration(on: 0)
        }
        saveIterationsInfo()
        stopIteration()
        currentIterationNumber = 0
        timer.invalidate()
        secondomer.invalidate()
        self.flowView?.changeTime(time: "--:--", iterationState: iterationState, i: (currentExerciseNumber, -1), stop: true)
        self.currentIteration = nil
        self.currentExercise = nil
        editTraining(wiht: dataSource?.currentTraining?.id ?? 0, success: {})
        finish()
    }
    
    func eventWithTimer(time: Int) {
        var min = 0
        var sec = 0
        var minStr = ""
        var secStr = ""
        min = Int(time/60)
        sec = time - min*60
        if min < 0 {
            min = 0
        }
        if sec < 0 {
            sec = 0
        }

        minStr = min<10 ? "0\(min)" : "\(min)"
        secStr = sec<10 ? "0\(sec)" : "\(sec)"

        var timeString = "-"+minStr+":"+secStr
        if iterationState == .rest || secondomerStarted {
            timeString.removeFirst()
        }
        self.audioEffect(on: time)

        self.flowView?.changeTime(time: timeString, iterationState: iterationState, i: (currentExerciseNumber, currentIterationNumber), stop: false)
    }
    
    private func audioEffect(on time: Int) {
        if time < 4 && !secondomerStarted {
            AudioServicesPlayAlertSound(SystemSoundID(1313))
        }
    }
    
    func saveIterationsInfo() {
        try! realm.performWrite {
            switch iterationState {
            case .work:
                if secondomerStarted {
                    currentIteration?.workTime = secondomerTime
                } else {
                    if currentIteration?.startTimerOnZero == false && currentIteration?.workTime == 0 {
                        currentIteration?.workTime = 0
                    } else {
                        currentIteration?.workTime = (currentIteration?.workTime ?? 0) - currentWorkTime
                    }
                }
            case .rest:
                if secondomerStarted {
                    currentIteration?.restTime = secondomerTime
                } else {
                    if currentIteration?.startTimerOnZero == false && currentIteration?.restTime == 0 {
                        currentIteration?.restTime = 0
                    } else {
                        currentIteration?.restTime = (currentIteration?.restTime ?? 0) - currentRestTime
                    }
                }
            }
            currentIteration?.wasSync = false
        }
        self.flowView?.rewriteIterations()
    }
    
}
