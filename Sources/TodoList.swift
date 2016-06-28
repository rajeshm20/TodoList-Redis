/**
 * Copyright IBM Corporation 2016
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 **/

import Foundation

import LoggerAPI
import TodoListAPI

import SwiftRedis


// Collection names
let TODOSET = "todoset"
let TODO = "todo"

// Field names
let TITLE = "title"
let COMPLETED = "completed"
let ORDER = "order"

// Redis operations
let ZCARD = "ZCARD"
let HGET = "HGET"
let HMSET = "HMSET"
let ZREMRANGEBYSCORE = "ZREMRANGEBYSCORE"
let ZRANGE = "ZRANGE"
let INCR = "INCR"
let ZADD = "ZADD"
let HSET = "HSET"
let ZREM = "ZREM"
let DEL = "DEL"
let INF = "inf"


/// TodoList for Redis
public class TodoListRedis: TodoListAPI {
    
    static let DefaultRedisHost = "localhost"
    static let DefaultRedisPort: UInt16 = 6379
    
    var host: String = TodoListRedis.DefaultRedisHost
    var port: UInt16 = TodoListRedis.DefaultRedisPort
    var password: String?
    
    
    /**
     Returns a Redis DAO for the TodoCollection. Stores the title, whether it is completed, and
     also a sorted order for displaying the items.
     
     - parameter address: IP address for the Redis server
     - parameter port: port number for Redis server
     - parameter password: optional password for Redis server
     */
    public init(host: String = TodoListRedis.DefaultRedisHost,
                port: UInt16 = TodoListRedis.DefaultRedisPort, password: String? = nil ) {
        
        self.host = host
        self.port = port
        self.password = password
    }
    
    public convenience init?(config: DatabaseConfiguration) {
        
        guard let host = config.host else {
            return nil
        }
        
        guard let port = config.port else {
            return nil
        }
        
        self.init(host: host, port: port, password: config.password)
    }
    
    private func connectRedis() throws -> Redbird  {
        let config = RedbirdConfig(address: host, port: port, password: password)
        let client = try Redbird(config: config)
        return client
    }
    
    /**
     Returns the total number in the collection.
     
     Uses the ZCARD operation to return the cardinality of the sorted set TODOSET
     
     - returns: size of set.
     */
    public func count(withUserID: String?, oncompletion: (Int?, ErrorProtocol?) -> Void) {
        
        
            let client = Redis()
            client.connect(host: self.host, port: self.port)
            let count = try client.command(ZCARD, params: [TODOSET]).toInt()
            oncompletion(count, nil)
        
    }
    
    /**
     Returns a todo item matching an ID
     
     Uses the HGET operation to get the hash for each of the fields.
     
     - parameter id: the ID for the todo item (ex. todo:20)
     */
    private func lookup( id: String) -> TodoItem? {
        
        do {
            let client = try connectRedis()
            let title = try client.command(HGET, params: [id, TITLE]).toString()
            let completedString = try client.command(HGET, params: [id, COMPLETED]).toString()
            let order = try client.command(HGET, params: [id, ORDER]).toString()
            
            let completed = completedString == "true" ? true : false
            guard let orderNumber = Int(order) else {
                Log.error("Could not parse order as Integer")
                return nil
            }
            
            return TodoItem(documentID: id, order: orderNumber, title: title, completed: completed)
            
        } catch {
            Log.error("Could not connect to Redis: \(error)")
        }
        
        return nil
    }
    
    /**
     Clears the entire todo collection
     
     Uses the ZREMRANGEBYSCORE operation to clear the sorted set. Uses the DEL operation on
     each of the keys.
     
     - parameter: callback
     */
    func clear(withUserID: String?, oncompletion: (ErrorProtocol?) -> Void) {
        
        do {
            let client = try connectRedis()
            try client.command(ZREMRANGEBYSCORE, params: [TODOSET, "-inf", "(inf"])
        } catch {
            Log.error("Could not connect to Redis: \(error)")
        }
        
        oncompletion()
    }
    
    func get(withUserID: String?, oncompletion: ([TodoItem]?, ErrorProtocol?) -> Void) {
        
        var todoItems = [TodoItem]()
        
        do {
            let client = try connectRedis()
            let responseArray = try client.command(ZRANGE, params: [TODOSET, "0", "-1"]).toArray()
            
            for item in responseArray {
                
                guard let item = try? item.toString() else {
                    continue
                }
                
                if let i = lookup(id: item ) {
                    todoItems.append(i)
                }
                
            }
            
        } catch {
            Log.error("Could not connect to Redis: \(error)")
        }
        
        oncompletion( todoItems, nil )
        
    }
    
    public func get(_ id: String, oncompletion: (TodoItem?) -> Void ) {
        
        let i = lookup(id: id )
        
        oncompletion( i )
    }
    
    public func add(title: String, order: Int = 0, completed: Bool = false, oncompletion: (TodoItem) -> Void ) throws {
        
        do {
            let client = try connectRedis()
            let id = try client.command(INCR, params: ["todo:id"]).toInt()
            let addHashResponse = try client.command(HMSET, params: ["todo:\(id)", TITLE, title, COMPLETED, String(completed), ORDER, String(order)]).toString()
            // check if OK
            if addHashResponse != "OK" {
                throw TodoCollectionError.creationError(title)
            }
            
            let addSetResponse = try client.command("ZADD", params: [TODOSET, String(order), "\(TODO):\(id)"]).toInt()
            
            if addSetResponse != 1 {
                Log.error("Did not add an element")
            }
            
            let newItem = TodoItem(id: "todo:\(id)",
                                   order: order,
                                   title: title,
                                   completed: completed        )
            oncompletion( newItem )
            
        } catch {
            Log.error("Could not connect to Redis: \(error)")
            
        }
        
    }
    
    public func update(id: String, title: String?, order: Int?, completed: Bool?, oncompletion: (TodoItem?) -> Void ) {
        
        do {
            let client = try connectRedis()
            if let title = title {
                try client.command(HSET, params: [id, TITLE, title])
            }
            
            if let completed = completed {
                let completedString = completed ? "true" : "false"
                try client.command(HSET, params: [id, COMPLETED, completedString])
            }
            
            if let order = order {
                try client.command(HSET, params: [id, ORDER, String(order)])
            }
            
            
            get(id) {
                todoitem in
                
                oncompletion(todoitem)
            }
            
            
            
        } catch {
            Log.error("Could not connect to Redis: \(error)")
        }
        
    }
    
    public func delete(_ id: String, oncompletion: (Void) -> Void) {
        
        do {
            let client = try connectRedis()
            try client.command(ZREM, params: [TODOSET, id])
            try client.command(DEL, params: [id])
            
        } catch {
            Log.error("Could not connect to Redis: \(error)")
            
        }
        
        oncompletion()
        
    }
    
    
    
    
}