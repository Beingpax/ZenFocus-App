import Foundation
import CoreData

class NextTaskManager {
    static let shared = NextTaskManager()
    
    private init() {}
    
    func getNextTask(context: NSManagedObjectContext) -> ZenFocusTask? {
        let fetchRequest: NSFetchRequest<ZenFocusTask> = ZenFocusTask.fetchRequest()
        
        // Fetch tasks scheduled for today and not completed
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
        
        fetchRequest.predicate = NSPredicate(format: "scheduledDate >= %@ AND scheduledDate < %@ AND isCompleted == NO", today as NSDate, tomorrow as NSDate)
        
        // Sort by custom order (which reflects the order in the Kanban board)
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \ZenFocusTask.customOrder, ascending: true)]
        
        // Limit to 1 to get only the next task
        fetchRequest.fetchLimit = 1
        
        do {
            let tasks = try context.fetch(fetchRequest)
            return tasks.first
        } catch {
            ZenFocusLogger.shared.error("Error fetching next task: \(error.localizedDescription)")
            return nil
        }
    }
}