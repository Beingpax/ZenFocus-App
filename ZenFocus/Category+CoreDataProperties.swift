//
//  Category+CoreDataProperties.swift
//  ZenFocus
//
//  Created by Prakash Joshi on 04/09/2024.
//
//

import Foundation
import CoreData

extension Category {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<Category> {
        return NSFetchRequest<Category>(entityName: "Category")
    }

    @NSManaged public var name: String?
    @NSManaged public var colorData: Data?
    @NSManaged public var parent: Category?
    @NSManaged public var children: NSSet?
    @NSManaged public var tasks: NSSet?
}

// MARK: Generated accessors for children
extension Category {
    @objc(addChildrenObject:)
    @NSManaged public func addToChildren(_ value: Category)

    @objc(removeChildrenObject:)
    @NSManaged public func removeFromChildren(_ value: Category)

    @objc(addChildren:)
    @NSManaged public func addToChildren(_ values: NSSet)

    @objc(removeChildren:)
    @NSManaged public func removeFromChildren(_ values: NSSet)
}

// MARK: Generated accessors for tasks
extension Category {
    @objc(addTasksObject:)
    @NSManaged public func addToTasks(_ value: ZenFocusTask)

    @objc(removeTasksObject:)
    @NSManaged public func removeFromTasks(_ value: ZenFocusTask)

    @objc(addTasks:)
    @NSManaged public func addToTasks(_ values: NSSet)

    @objc(removeTasks:)
    @NSManaged public func removeFromTasks(_ values: NSSet)
} 