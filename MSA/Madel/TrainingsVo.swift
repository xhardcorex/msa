//
//  TrainingsVo.swift
//  MSA
//
//  Created by Pavlo Kharambura on 8/28/18.
//  Copyright © 2018 Pavlo Kharambura. All rights reserved.
//

import Foundation
import Realm
import RealmSwift

class TrainingTemplate: Object {
    @objc dynamic var id: Int = -1
    @objc dynamic var name: String = ""
    @objc dynamic var trianerId: String = ""
    @objc dynamic var typeId: Int = -1
    @objc dynamic var days: Int = 0
    @objc dynamic var trainingId: Int = -1
    
    @objc dynamic var wasSync: Bool = false
    
    
    
    override static func primaryKey() -> String? {
        return "id"
    }
    
    func incrementID() -> Int {
        let realm = try! Realm()
        return (realm.objects(TrainingTemplate.self).max(ofProperty: "id") as Int? ?? 0) + 1
    }
}

class Training: Object {
    @objc dynamic var id: Int = -1
    @objc dynamic var name: String = ""
    @objc dynamic var trianerId: String = ""
    @objc dynamic var userId: Int = -1
    var weeks = List<TrainingWeek>()
    
    @objc dynamic var wasSync: Bool = false

    override static func primaryKey() -> String? {
        return "id"
    }
    
    func incrementID() -> Int {
        let realm = try! Realm()
        return (realm.objects(Training.self).max(ofProperty: "id") as Int? ?? 0) + 1
    }
}

class TrainingWeek: Object {
    @objc dynamic var id: Int = -1
    var days = List<TrainingDay>()

    @objc dynamic var wasSync: Bool = false

    override static func primaryKey() -> String? {
        return "id"
    }
    
    func incrementID() -> Int {
        let realm = try! Realm()
        return (realm.objects(TrainingWeek.self).max(ofProperty: "id") as Int? ?? 0) + 1
    }
}

class TrainingDay: Object {
    @objc dynamic var id: Int = -1
    @objc dynamic var name: String = ""
    @objc dynamic var date: String = ""
    @objc dynamic var roundTraining: Bool = false
    var exercises = List<ExerciseInTraining>()
    
    @objc dynamic var wasSync: Bool = false

    override static func primaryKey() -> String? {
        return "id"
    }
    
    func incrementID() -> Int {
        let realm = try! Realm()
        return (realm.objects(TrainingDay.self).max(ofProperty: "id") as Int? ?? 0) + 1
    }
}

class ExerciseInTraining: Object {
    @objc dynamic var id: Int = -1
    @objc dynamic var name: String = ""
    @objc dynamic var exerciseId: Int = -1
    @objc dynamic var byTrainer: Bool = false
    var iterations = List<Iteration>()
    
    @objc dynamic var wasSync: Bool = false

    override static func primaryKey() -> String? {
        return "id"
    }
    
    func incrementID() -> Int {
        let realm = try! Realm()
        return (realm.objects(ExerciseInTraining.self).max(ofProperty: "id") as Int? ?? 0) + 1
    }
}

class Iteration: Object {
    @objc dynamic var id: Int = -1
    @objc dynamic var exerciseInTrainingId: Int = -1
    @objc dynamic var weight: Int = 0
    @objc dynamic var counts: Int = 0
    @objc dynamic var workTime: Int = 0
    @objc dynamic var restTime: Int = 0

    @objc dynamic var wasSync: Bool = false
    
    override static func primaryKey() -> String? {
        return "id"
    }
    
    func incrementID() -> Int {
        let realm = try! Realm()
        return (realm.objects(Iteration.self).max(ofProperty: "id") as Int? ?? 0) + 1
    }
}