// Import Dependencies
const url = require('url')
const MongoClient = require('mongodb').MongoClient

// Create cached connection variable
let cachedDb = null

// A function for connecting to MongoDB,
// taking a single parameter of the connection string
async function connectToDatabase(uri) {
  // If the database connection is cached,
  // use it instead of creating a new connection
  if (cachedDb) {
    return cachedDb
  }

  // If no connection is cached, create a new one
  const client = await MongoClient.connect(uri, { useNewUrlParser: true })

  // Select the database through the connection,
  // using the database path of the connection string
  const db = await client.db(url.parse(uri).pathname.substr(1))

  // Cache the database connection and return the connection
  cachedDb = db
  return db
}

// The main, exported, function of the endpoint,
// dealing with the request and subsequent response
module.exports = async (req, res) => {
  // Get a database connection, cached or otherwise,
  // using the connection string environment variable as the argument
  const db = await connectToDatabase(process.env.MONGODB_URI)

  // Select the "users" collection from the database
  const collection = await db.collection(process.env.MONGODB_COLLECTION)

  // Query for a movie that has the title 'The Room'
  const query_servers = {};
  const options_servers = {
    // sort matched documents in descending order by rating
    sort: { name: 1 },
    // Include only the `title` and `imdb` fields in the returned document
    projection: { _id: 0 }
  };
  // Select the users collection from the database
  const servers = await collection.find(query_servers, options_servers).toArray()

  // Respond with a JSON string of all users in the collection
  res.status(200).json({ servers })
}
