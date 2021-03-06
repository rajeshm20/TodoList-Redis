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

let TODO = "todo"

// Field names
let TITLE = "title"
let COMPLETED = "completed"
let ORDER = "order"
let USERID = "userid"

/// TodoList for Redis
public class TodoList: TodoListAPI {
    static let NegInf = "-inf"
    static let Inf = "(inf"
    static let DefaultRedisHost = "localhost"
    static let DefaultRedisPort = Int32(6379)
    static let DefaultRedisPassword = ""
    var redis: Redis!

    var host: String = TodoList.DefaultRedisHost
    var port: Int32 = TodoList.DefaultRedisPort
    var password: String = TodoList.DefaultRedisPassword
    var defaultUsername = "default"

    /**
     Returns a Redis DAO for the TodoCollection. Stores the title, whether it is completed, and
     also a sorted order for displaying the items.

     - parameter address: IP address for the Redis server
     - parameter port: port number for Redis server
     - parameter password: optional password for Redis server
     */
    public init(host: String = TodoList.DefaultRedisHost,
                port: Int32 = TodoList.DefaultRedisPort,
                password: String = TodoList.DefaultRedisPassword ) {

        self.host = host
        self.port = port
        self.password = password
        self.redis = Redis()
    }

    public init(config: DatabaseConfiguration) {

        self.host = config.host!
        self.port = Int32(config.port!)
        self.password = config.password!
        self.redis = Redis()
    }

    private func connectRedis(callback: (NSError?) -> Void) {

        if !redis.connected {

            redis.connect(host: host, port: port) {
                error in

                guard error == nil else {
                    Log.error("Failed to connect to Redis server")
                    callback(error)
                    return
                }
                
                Log.info("Authenicate password for Redis")
                self.redis.auth(self.password) {
                    error in
                    
                    guard error != nil else {
                        Log.error("Failed to authenicate to Redis server")
                        
                        callback(error)
                        return
                    }
                    callback(nil)
                }

            }
        } else {
            Log.info("Already connected to Redis server")
            callback(nil)
        }
    }

    public func count(withUserID: String?, oncompletion: (Int?, ErrorProtocol?) -> Void) {

        let userID = withUserID ?? defaultUsername

        connectRedis() {
            connectionError in

            guard connectionError == nil else {
                Log.error("Unable to connect to Redis server")
                oncompletion(nil, connectionError)
                return
            }
            self.redis.zcard(userID) {
                result, error in

                guard error == nil else {
                    Log.error("Failed to return the cardinality")
                    oncompletion(nil, error)
                    return
                }

                oncompletion(result, error)
            }
        }
    }

    public func clear(withUserID: String?, oncompletion: (ErrorProtocol?) -> Void) {

        let userID = withUserID ?? defaultUsername

        connectRedis() {
            connectionError in

            guard connectionError == nil else {
                Log.error("Unable to connect to Redis server")
                oncompletion(connectionError)
                return
            }

            self.redis.zrange(userID, start: 0, stop: -1) {
                result, error in

                guard error == nil else {
                    Log.error("Failed to return list of all document ID(s)")
                    oncompletion(error)
                    return
                }
                guard let result = result else {
                    Log.error("Unable to parse")
                    oncompletion(TodoCollectionError.ParseError)
                    return
                }

                for item in result {

                    self.redis.del((item?.asString)!) {
                        result2, error2 in

                        guard error2 == nil else {
                            Log.error("Failed to delete an item")
                            oncompletion(error2)
                            return
                        }
                    }
                }
            }

            self.redis.zremrangebyscore(userID, min: TodoList.NegInf, max: TodoList.Inf) {
                result, error in

                guard error == nil else {
                    Log.error("Failed to remove all elements")
                    oncompletion(error)
                    return
                }
            }

            oncompletion(nil)
        }
    }


    public func clearAll(oncompletion: (ErrorProtocol?) -> Void) {

        connectRedis() {
            connectionError in

            guard connectionError == nil else {
                Log.error("Unable to connect to Redis server")
                oncompletion(connectionError)
                return
            }

            self.redis.flushdb() {
                result, error in

                guard result else {
                    Log.error("Failed to delete all the keys")
                    oncompletion(error)
                    return
                }
            }

            oncompletion(nil)
        }
    }


    public func get(withUserID: String?, oncompletion: ([TodoItem]?, ErrorProtocol?) -> Void) {

        let userID = withUserID ?? defaultUsername

        connectRedis() {
            connectionError in

            guard connectionError == nil else {
                Log.error("Unable to connect to Redis server")
                oncompletion(nil, connectionError)
                return
            }

            var todoItems = [TodoItem]()

            self.redis.zrange(userID, start: 0, stop: -1) {
                result, error in

                guard error == nil else {
                    Log.error("Failed to return list of all document ID(s)")
                    oncompletion(nil, error)
                    return
                }

                guard let result = result else {
                    Log.error("Failed to parse")
                    oncompletion(nil, TodoCollectionError.ParseError)
                    return
                }

                for item in result {
                    guard let item = item else {
                        continue
                    }

                    self.lookup(documentId: item.asString) {
                        todoResult, error in

                        guard error == nil else {
                            Log.error("Failed to lookup the Todo Item")
                            oncompletion(nil, error)
                            return
                        }

                        todoItems.append(todoResult!)
                    }
                }
            }

            oncompletion(todoItems, nil)
        }
    }

    public func get(withUserID: String?, withDocumentID: String,
                    oncompletion: (TodoItem?, ErrorProtocol?) -> Void ) {

        let userID = withUserID ?? defaultUsername
        self.lookup(documentId: withDocumentID) {
            result, error in

            guard error == nil else {
                Log.error("Failed to lookup the Todo Item")
                oncompletion(nil, error)
                return
            }

            guard userID == result?.userID else {
                Log.error("Result is nil")
                oncompletion(nil, TodoCollectionError.AuthError)
                return
            }

            oncompletion(result, error)
        }
    }


    public func add(userID: String?, title: String, order: Int = 0,
                    completed: Bool = false,
                    oncompletion: (TodoItem?, ErrorProtocol?) -> Void ) {

        let userID = userID ?? defaultUsername
        connectRedis() {
            connectionError in

            guard connectionError == nil else {
                Log.error("Unable to connect to Redis server")
                oncompletion(nil, connectionError)
                return
            }

            self.redis.incr("todo:id") {
                incrResult, incrError in

                guard incrError == nil else {
                    Log.error("Failed to increment the key")
                    oncompletion(nil, incrError)
                    return
                }

                self.redis.hmset(String(incrResult), fieldValuePairs: (TITLE, title),
                                 (ORDER, String(order)), (COMPLETED, String(completed)),
                                 (USERID, userID)) {
                                    result, error in

                                    guard result && error == nil else {
                                        Log.error("Failed to create an hashmap set")
                                        oncompletion(nil, error)
                                        return
                                    }

                                    self.redis.zadd(userID, tuples: (order, String(incrResult))) {
                                        result2, error2 in

                                        guard result2 == 1 && error2 == nil else {
                                            Log.error("Failed to add the tuple")
                                            oncompletion(nil, error2)
                                            return
                                        }

                                        let newItem = TodoItem(documentID: String(incrResult),
                                                               userID: userID, order: order,
                                                               title: title, completed: completed)

                                        oncompletion(newItem, nil)
                                    }
                }
            }
        }
    }

    public func update(documentID: String, userID: String?, title: String?, order: Int?,
                       completed: Bool?, oncompletion: (TodoItem?, ErrorProtocol?) -> Void ) {

        connectRedis() {
            connectionError in

            guard connectionError == nil else {
                Log.error("Unable to connect to Redis server")
                oncompletion(nil, connectionError)
                return
            }

            var fieldValuePairs = [(String, String)]()
            
            if let title = title {
                fieldValuePairs.append((TITLE, title))
            }

            if let order = order {
                fieldValuePairs.append((ORDER, String(order)))
            }

            if let completed = completed {
                let completedString = completed ? "true" : "false"
                fieldValuePairs.append((COMPLETED, completedString))
            }
            
            self.redis.hmsetArrayOfKeyValues(documentID, fieldValuePairs: fieldValuePairs) {
                result, error in
                
                guard result && error == nil else {
                    Log.error("Failed to create an hashmap set")
                    oncompletion(nil, error)
                    return
                }
            }

            self.get(withUserID: userID, withDocumentID: documentID) {
                result, error in
                
                oncompletion(result, error)
            }
        }
    }

    public func delete(withUserID: String?, withDocumentID: String, oncompletion: (ErrorProtocol?) -> Void) {

        let userID = withUserID ?? defaultUsername

        connectRedis() {
            connectionError in

            guard connectionError == nil else {
                Log.error("Unable to connect to Redis server")
                oncompletion(connectionError)
                return
            }

            self.redis.zrem(userID, members: withDocumentID) {
                result, error in

                guard result == 1 && error == nil else {
                    Log.error("Failed to remove the specified item")
                    oncompletion(error)
                    return
                }

                self.redis.del(userID) {
                    result2, error2 in

                    guard error2 == nil else {
                        Log.error("Failed to delete the specific key")
                        oncompletion(error2)
                        return
                    }

                    oncompletion(nil)
                }
            }
        }
    }

    private func lookup(documentId: String, oncompletion: (TodoItem?, ErrorProtocol?) -> Void) {

        connectRedis() {
            connectionError in

            guard connectionError == nil else {
                Log.error("Unable to connect to Redis server")
                oncompletion(nil, connectionError)
                return
            }

            self.redis.hmget(documentId, fields: TITLE, ORDER, COMPLETED, USERID) {
                result, error in


                guard let result = result where error == nil else {
                    Log.error("Could not parse")
                    oncompletion(nil, error)
                    return
                }

                guard let userID = result[3]?.asString else {
                    Log.error("Could not parse userID as String")
                    oncompletion(nil, TodoCollectionError.ParseError)
                    return
                }

                guard let title = result[0]?.asString else {
                    Log.error("Could not parse title as String")
                    oncompletion(nil, TodoCollectionError.ParseError)
                    return
                }

                let completed = result[2]?.asString == "true" ? true : false

                guard let order = result[1]?.asInteger else {
                    Log.error("Could not parse order as Integer")
                    oncompletion(nil, TodoCollectionError.ParseError)
                    return
                }

                oncompletion(TodoItem(documentID: documentId, userID: userID, order: order, title: title, completed: completed), nil)

            }
        }
    }
}
