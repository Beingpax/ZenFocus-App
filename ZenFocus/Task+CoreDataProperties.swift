//
//  Task+CoreDataProperties.swift
//  ZenFocus
//
//  Created by Prakash Joshi on 04/09/2024.
//
//

import Foundation
import CoreData

extension ZenFocusTask {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<ZenFocusTask> {
        return NSFetchRequest<ZenFocusTask>(entityName: "ZenFocusTask")
    }

    @NSManaged public var title: String?
    @NSManaged public var createdAt: Date?
    @NSManaged public var isCompleted: Bool
    @NSManaged public var category: String?
    @NSManaged public var focusedDuration: Double
    @NSManaged public var completedAt: Date?
    @NSManaged public var isInDailyFocus: Bool
    @NSManaged public var dailyFocusOrder: Int32
    @NSManaged public var scheduledDate: Date?
    @NSManaged public var customOrder: Int32
    @NSManaged public var categoryRef: Category?
}

extension ZenFocusTask : Identifiable {

}

