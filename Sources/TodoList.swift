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
// let TODOSET = "todoset"

let TODO = "todo"

// Field names
let TITLE = "title"
let COMPLETED = "completed"
let ORDER = "order"
let USERID = "userid"

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
public class TodoList: TodoListAPI {
    
    static let DefaultRedisHost = "localhost"
    static let DefaultRedisPort = Int32(6379)
    var redis: Redis!
    
    var host: String = TodoList.DefaultRedisHost
    var port: Int32 = TodoList.DefaultRedisPort
    var password: String?
    
    var defaultUsername = "default"
    
    
    /**
     Returns a Redis DAO for the TodoCollection. Stores the title, whether it is completed, and
     also a sorted order for displaying the items.
     
     - parameter address: IP address for the Redis server
     - parameter port: port number for Redis server
     - parameter password: optional password for Redis server
     */
    public init(host: String = TodoList.DefaultRedisHost,
                port: Int32 = TodoList.DefaultRedisPort, password: String? = "" ) {
        
        self.host = host
        self.port = port
        self.password = password
        self.redis = Redis()
    }
    
    public convenience init?(config: DatabaseConfiguration) {
        
        guard let host = config.host else {
            return nil
        }
        
        guard let port = config.port else {
            return nil
        }
        self.init(host: host, port: Int32(port), password: config.password)
    }
    
    private func connectRedis(callback: (NSError?) -> Void) {
        if !redis.connected  {
            Log.info("Connecting to Redis")
            print("Connecting to Redis")
            
            redis.connect(host: host, port: port) {
                error in
                
                guard error == nil else {
                    Log.error("Failed to connect to Redis server")
                    print("Failed to connect to Redis server")
                    print(error)
                    callback(error)
                    return
                }
                
                Log.info("Authenicate password for Redis")
                print("Authenicate password for Redis")
                self.redis.auth(self.password!) {
                    error in

                    print(error)
                    guard error != nil else {
                        Log.error("Failed to authenicate to Redis server")
                        print("Failed to authenicate to Redis server")
                        callback(error)
                        return
                    }
                    callback(nil)
                }
            }
        } else {
            Log.info("Already connected to Redis server")
            print("Already connected to Redis server")
            callback(nil)
        }
        
    }
    
    /**
     Returns the total number in the collection.
     
     Uses the ZCARD operation to return the cardinality of the sorted set TODOSET
     
     - returns: size of set.
     */
    
    public func count(withUserID: String?, oncompletion: (Int?, ErrorProtocol?) -> Void) {
        
        let userid = withUserID != nil ? withUserID! : defaultUsername
        
        connectRedis(){
            connectionError in
            
            guard connectionError == nil else {
                oncompletion(nil, connectionError)
                return
            }
            self.redis.zcard(userid, callback: {
                (result: Int?, error: NSError?) in
                
                guard error == nil else {
                    oncompletion(nil, error)
                    return
                }
                
                oncompletion(result, error)
            })
        }
    }
    
    /**
     Clears the entire todo collection
     
     Uses the ZREMRANGEBYSCORE operation to clear the sorted set. Uses the DEL operation on
     each of the keys.
     
     - parameter: callback
     */
    public func clear(withUserID: String?, oncompletion: (ErrorProtocol?) -> Void) {
        let userid = withUserID != nil ? withUserID! : defaultUsername
        
        connectRedis(){
            connectionError in
            
            guard connectionError == nil else {
                oncompletion(connectionError)
                return
            }
            
            self.redis.zrange(userid, start: 0, stop: -1)  {
                (result: [RedisString?]?, error: NSError?) in
                
                guard error == nil else {
                    oncompletion(error)
                    return
                }
                
                for item in result! {
                    
                    self.redis.del(String(item), callback: {
                        (result2:Int?, error2:NSError?) in
                        
                        guard error2 == nil else {
                            oncompletion(error2)
                            return
                        }
                    })
                }
            }
            
            self.redis.zremrangebyscore(userid, min: "-inf", max: "(inf", callback: {
                (result:Int?, error: NSError?) in
                
                guard error == nil else {
                    oncompletion(error)
                    return
                }
            })
            oncompletion(nil)
        }
    }
    
    
    public func clearAll(oncompletion: (ErrorProtocol?) -> Void) {
        connectRedis(){
            connectionError in
            
            print(connectionError)
            
            guard connectionError == nil else {
                oncompletion(connectionError)
                return
            }
            
            self.redis.flushdb() {
                (result: Bool, error: NSError?) in
                
                guard result == true else {
                    oncompletion(error)
                    return
                }
            }
            
            oncompletion(nil)
        }
    }
    
    
    public func get(withUserID: String?, oncompletion: ([TodoItem]?, ErrorProtocol?) -> Void) {
        let userid = withUserID != nil ? withUserID! : defaultUsername
        
        connectRedis(){
            connectionError in
            
            guard connectionError == nil else {
                oncompletion(nil, connectionError)
                return
            }
            
            var todoItems = [TodoItem]()
            
            self.redis.zrange(userid, start: 0, stop: -1, callback: {
                (result:[RedisString?]?, error: NSError?) in
                
                for item in result! {
                    self.lookup(documentId: item!.asString, oncompletion: {
                        (todoResult: TodoItem?, error: ErrorProtocol?) in
                        
                        todoItems.append(todoResult!)
                    })
                
                }
            })
            oncompletion(todoItems, nil)
        
        }
    }

    public func get(withUserID: String?, withDocumentID: String, oncompletion: (TodoItem?, ErrorProtocol?) -> Void ) {
        let userid = withUserID != nil ? withUserID! : defaultUsername
        self.lookup(documentId: withDocumentID) {
            (result: TodoItem?, error: ErrorProtocol?) in
            
            // check to see the userid matches the user id in the hashset
            guard userid == result!.userID! else {
                oncompletion(nil, error)
                return
            }
            
            oncompletion(result, error)
        }
    }
    
    
    public func add(userID: String?, title: String, order: Int = 0, completed: Bool = false, oncompletion: (TodoItem?, ErrorProtocol?) -> Void ){
        let userid = userID != nil ? userID! : defaultUsername
        connectRedis(){
            connectionError in
            
            guard connectionError == nil else {
                oncompletion(nil, connectionError)
                return
            }
            
            self.redis.incr("todo:id", callback: {
                (incrResult: Int?, incrError: NSError?) in
                
                guard incrError == nil else {
                    oncompletion(nil, incrError)
                    return
                }
                
                self.redis.hmset(String(incrResult),
                                 fieldValuePairs: (TITLE, title), (ORDER, String(order)), (COMPLETED, String(completed)),
                                 (USERID, userid)) {
                                    
                    (result:Bool, error: NSError?) in

                    guard result == true else {
                    oncompletion(nil, error)
                    return
                }
                
                self.redis.zadd(userid, tuples: (order,String(incrResult)), callback: {
                    (result2:Int?, error2: NSError?) in
                    
                    guard result2 == 1 else {
                        print("did not add an element")
                        oncompletion(nil, error2)
                        return
                    }
                    let newItem = TodoItem(documentID: String(incrResult), userID: userid, order: order, title: title, completed: completed)
                    
                    print("add the todo item")
                    oncompletion(newItem, error2)
                })
            }
                
        })
       }
    }
    
    private func lookup(documentId: String?, oncompletion: (TodoItem?, ErrorProtocol?) -> Void) {
        connectRedis(){
            connectionError in
            print("this is lokup function")
            print(documentId)
            guard connectionError == nil else {
                oncompletion(nil, connectionError)
                return
            }
            self.redis.hmget(documentId!, fields: TITLE, ORDER, COMPLETED, USERID,  callback: {
                (result:[RedisString?]?, error: NSError?) in
                
                guard error == nil else {
                    oncompletion(nil,error)
                    return
                }
                print("lookup function")
                print(result)
                print(result![3]?.asString)
                let userID = result![3]!.asString
                let title = result![0]!.asString
                let completed = result![2]!.asString == "true" ? true : false
                guard let order = result?[1]?.asInteger else {
                    print("could not parse order as Integer")
                    Log.error("Could not parse order as Integer")
                    oncompletion(nil, nil)
                    return
                }
                
                oncompletion(TodoItem(documentID: documentId!, userID: userID, order: order, title: title, completed: completed), error)
                
            })
        }
    }
    
    public func update(documentID: String, userID: String?, title: String?, order: Int?,
                       completed: Bool?, oncompletion: (TodoItem?, ErrorProtocol?) -> Void ) {
        connectRedis(){
            connectionError in
            
            guard connectionError == nil else {
                oncompletion(nil,connectionError)
                return
            }
            
            if let title = title {
                self.redis.hmset(documentID, fieldValuePairs: (TITLE, title), callback: {
                    (result:Bool, error: NSError?) in
                    
                    guard error == nil else {
                        oncompletion(nil, error)
                        return
                    }
                })
            }
            
            if let order = order {
                self.redis.hmset(documentID, fieldValuePairs: (ORDER, String(order)), callback: {
                    (result:Bool, error: NSError?) in
                    
                    guard error == nil else {
                        oncompletion(nil, error)
                        return
                    }
                })
            }
            
            if let completed = completed {
                let completedString = completed ? "true" : "false"
                self.redis.hmset(documentID, fieldValuePairs: (COMPLETED, completedString), callback: {
                    (result:Bool, error: NSError?) in
                    
                    guard error == nil else {
                        oncompletion(nil, error)
                        return
                    }
                })
            }
            
            self.get(withUserID: userID, withDocumentID: documentID, oncompletion: {
                (result:TodoItem?, error:ErrorProtocol?) in
                
                oncompletion(result,  error)
            })
        }
    }
    
    public func delete(withUserID: String?, withDocumentID: String, oncompletion: (ErrorProtocol?) -> Void) {
        connectRedis(){
            connectionError in
            
            guard connectionError == nil else {
                oncompletion(connectionError)
                return
            }
            
            self.redis.zrem(withUserID!, members: withDocumentID, callback: {
                (result:Int?, error: NSError?) in
                
                guard result == 1 else {
                    oncompletion(error)
                    return
                }
                
                self.redis.del(withUserID!, callback: {
                    (result2:Int?, error2:NSError?) in
                    
                    guard error2 == nil else {
                        oncompletion(error2)
                        return
                    }
                    
                    oncompletion(nil)
                })
            })
        }
    }
}