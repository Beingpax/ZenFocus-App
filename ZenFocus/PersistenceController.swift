import CoreData
import AppKit

struct PersistenceController {
    static let shared = PersistenceController()

    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "ZenFocus")
        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        }
        container.loadPersistentStores { (storeDescription, error) in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        }
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        container.viewContext.automaticallyMergesChangesFromParent = true
        
        // Add migration code here if needed
        migrateIfNeeded()
    }
    
    private func migrateIfNeeded() {
        guard let persistentStore = container.persistentStoreCoordinator.persistentStores.first,
              let storeURL = persistentStore.url else {
            return
        }
        
        let coordinator = container.persistentStoreCoordinator
        
        // Check if migration is needed
        if coordinator.managedObjectModel.isConfiguration(withName: nil, compatibleWithStoreMetadata: persistentStore.metadata) {
            return // No migration needed
        }
        
        do {
            // Perform lightweight migration
            try coordinator.addPersistentStore(
                ofType: NSSQLiteStoreType,
                configurationName: nil,
                at: storeURL,
                options: [
                    NSMigratePersistentStoresAutomaticallyOption: true,
                    NSInferMappingModelAutomaticallyOption: true
                ]
            )
            
            // Remove the old store
            try coordinator.remove(persistentStore)
            
            ZenFocusLogger.shared.info("Core Data migration completed successfully")
        } catch {
            ZenFocusLogger.shared.error("Failed to migrate store: \(error)")
        }
    }
    
    static var preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let viewContext = result.container.viewContext
        // Add some sample data here if needed
        return result
    }()
    
    func saveContext() {
        let context = container.viewContext
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                let nsError = error as NSError
                ZenFocusLogger.shared.error("Unresolved error saving context: \(nsError), \(nsError.userInfo)")
                
                // Show an alert to the user
                DispatchQueue.main.async {
                    let alert = NSAlert()
                    alert.messageText = "Error Saving Data"
                    alert.informativeText = "There was an error saving your data. Please try again or contact support if the problem persists."
                    alert.alertStyle = .warning
                    alert.addButton(withTitle: "OK")
                    alert.runModal()
                }
            }
        }
    }
    
    func isStoreAccessible() -> Bool {
        do {
            _ = try container.viewContext.count(for: NSFetchRequest<NSFetchRequestResult>(entityName: "ZenFocusTask"))
            return true
        } catch {
            ZenFocusLogger.shared.error("Error checking store accessibility: \(error.localizedDescription)")
            return false
        }
    }
}
