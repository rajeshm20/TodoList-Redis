# TodoList Redis

Implements the [TodoListAPI](https://github.com/IBM-Swift/todolist-api) for TodoList. Uses the [Kitura-Redis](https://github.com/IBM-Swift/todolist-api) library for interfacing with Redis.

Quick start:

1. Download the [Swift DEVELOPMENT 06-06 snapshot](https://swift.org/download/#snapshots)
2. Download redis
  
  You can use `brew install redis` or `apt-get install redis-server`

3. Clone the TodoList Redis repository

  `git clone https://github.com/IBM-Swift/todolist-redis`
  
4. Fetch the test cases by running:

  `git clone https://github.com/IBM-Swift/todolist-tests Tests`

5. Compile the library with `swift build` or create an XCode project with `swift build -X`

6. Run the test cases with `swift test` or directly from XCode
