# TodoList Redis

[![Build Status](https://travis-ci.org/IBM-Swift/todolist-redis.svg?branch=master)](https://travis-ci.org/IBM-Swift/todolist-redis)

Implements the [TodoListAPI](https://github.com/IBM-Swift/todolist-api) for TodoList. Uses the [Kitura-Redis](https://github.com/IBM-Swift/todolist-api) library for interfacing with Redis.

Quick start:
1. Download the [Swift DEVELOPMENT 06-06 snapshot](https://swift.org/download/#snapshots)

2. Download redis
  You can use `brew install redis` or `apt-get install redis-server`

3. Clone the TodoList Redis repository
  `git clone https://github.com/IBM-Swift/todolist-redis`

4. Fetch the test cases by running:
  `git clone https://github.com/IBM-Swift/todolist-tests Tests`

5. Compile the library with `swift build` or create an XCode project with `swift package generate-xcodeproj`
6. 
6. Run the test cases with `swift test` or directly from XCode

##Deploying to Bluemix:

1.Get an account for Bluemix

2.Select the Redis by Compose Service

3.Set the Service name as TodoList-Redis then initialize the Host, Port, Username, and Password to the values instantiated

4.Upon creation, you should see your unbound service on the dashboard page

5.Dowload and install the Cloud Foundry tools:

```
cf login
bluemix api https://api.ng.bluemix.net
bluemix login -u username -o org_name -s space_name
```

```
Be sure to change the directory to the todolist-mongodb directory where the manifest.yml file is located.
```

6.Run ```cf push```

7.It should take several minutes, roughly 4-6 minutes. If it works correctly, it should state

```
2 of 2 instances running
App started
```
