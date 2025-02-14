//
//  AWSService.swift
//  Cartrekk
//
//  Created by Daniel Yang on 2/13/25.
//

import Foundation
import AWSS3
import Smithy
import UIKit
import ClientRuntime
import AWSClientRuntime




let accessKey = ProcessInfo.processInfo.environment["AWS_ACCESS_KEY_ID"]
let secretKey = ProcessInfo.processInfo.environment["AWS_SECRET_ACCESS_KEY"]

/*func configureS3Client() async throws {
    let configuration = try await S3Client.S3ClientConfiguration()
    // configuration.region = "us-east-2" // Uncomment this to set the region programmatically.
    let client = S3Client(config: configuration)
    // Now you can use client for S3 operations
}
 */
func getBucketNames() async throws -> [String] {
    do {
        // Get an S3Client with which to access Amazon S3.
        print("trying config")
        
        let configuration = try await S3Client.S3ClientConfiguration()
        configuration.region = "us-west-1" // Uncomment this to set the region programmatically.
        print("config done")
        let client = S3Client(config: configuration)
        print("client made")

        // Use "Paginated" to get all the buckets.
        // This lets the SDK handle the 'continuationToken' in "ListBucketsOutput".
        let pages = client.listBucketsPaginated(
            input: ListBucketsInput( maxBuckets: 10)
        )
        print("1")

        // Get the bucket names.
        var bucketNames: [String] = []
        print("trying print pages")
        print(pages)
        print("passed")
        do {
            print("tryyop")
            for try await page in pages {
                print("trying1")
                guard let buckets = page.buckets else {
                    print("111")
                    print("Error: no buckets returned.")
                    continue
                }
                print("2")
                for bucket in buckets {
                    bucketNames.append(bucket.name ?? "<unknown>")
                }
            }

            return bucketNames
        } catch {
            print("YOYO")
            print("ERROR: listBuckets:", dump(error))
            throw error
        }
    }
}
func uploadImageToS3(image: UIImage?, imageName: String, bucketName: String) async throws -> String {
    // Convert UIImage to Data
    guard let image = image, let imageData = image.jpegData(compressionQuality: 0.5) else {
        throw NSError(domain: "ImageConversionError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to convert UIImage to Data"])
    }
    print("bruh its happening")
    // Configure the AWS S3 client
    let configuration = try await S3Client.S3ClientConfiguration()
    configuration.region = "us-west-1" // Set your region
    let s3 = S3Client(config: configuration)
    
    
   
    
    
    let imageName = "\(UUID().uuidString).jpg"
    
    print("bruh its happening1")
    // Create the putObject request
    let putObjectInput = PutObjectInput(
        
        body: .data(imageData),
        bucket: bucketName,
        checksumAlgorithm: .sha1,

        contentType: "image/jpeg",
        key: imageName
        
         // Adjust based on your image type
    )
    print("bruh its happening3")
    // Upload the image to S3
    do {
        // Attempt to upload the image
        let _ = try await s3.putObject(input: putObjectInput)
        print("Image uploaded successfullyhh!")
    } catch {
        // Catch any errors and handle them
        print("Upload failjjjjjjjed: \(error.localizedDescription)")
    }
    
              
    
    print("Image uploaded sufccessfully!")
    
    // Construct the URL of the uploaded image
    let imageURL = "https://\(bucketName).s3.us-west-1.amazonaws.com/\(imageName)"
    return imageURL
}

/*
private init() async {
    /*let accessKeyTop = ProcessInfo.processInfo.environment["AWS_ACCESS_KEY_ID"] ?? ""
    let secretKeyTop = ProcessInfo.processInfo.environment["AWS_SECRET_ACCESS_KEY"] ?? ""

    

    let credentials = AWSS3.Credentials(accessKeyId: accessKeyTop, secretAccessKey: secretKeyTop)
    let configuration = AWSS3.Configuration(region: .us_east_1, credentials: credentials)
    self.s3 = S3Client(configuration: configuration)

    
    self.s3 = S3Client(
        credentialsProvider:AWSStaticCredentialsProvider(accessKeyId: accessKeyTop, secretAccessKey: secretKeyTop
        ,
        region: "us-west-1")// Change this to match your AWS region
    )
    */
    
    
    
    
}
 */


/*
func uploadFile(bucketName: String, filePath: String, s3Key: String) async {
    let url = URL(fileURLWithPath: filePath)
    guard let fileData = try? Data(contentsOf: url) else {
        print(" Failed to read file data.")
        return
    }

    do {
        let input = PutObjectInput(
            body: .data(fileData),
            bucket: bucketName,
            key: s3Key
        )

        _ = try await s3.putObject(input: input)
        print("File uploaded successfully to (bucketName)/(s3Key)")
    } catch {
        print("Upload failed: (error)")
    }
}




*/
