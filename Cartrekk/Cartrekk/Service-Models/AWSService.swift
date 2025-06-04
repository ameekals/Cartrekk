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
import AWSCognitoIdentity
import Firebase
import FirebaseAuth

class AWSService {
    // MARK: - Configuration
    private let identityPoolId = "us-west-1:dd8da7ff-e1a1-4a36-9721-fc6a44f7db89" // Replace with your actual Identity Pool ID
    private let region = "us-west-1"
    private let bucketName = "cartrekk-images" // Replace with your actual S3 bucket name
    
    // MARK: - Singleton
    static let shared = AWSService()
    private init() {}
    
    // MARK: - Get or Create Cognito Identity for Firebase User
    func getCognitoIdentityForUser(firebaseUserId: String) async throws -> String {
        // First, check if user already has a Cognito Identity ID in Firebase
        
        
        
        
        if let existingCognitoId = try await getCognitoIdFromFirebase(firebaseUserId: firebaseUserId) {
            print("Found existing Cognito ID: \(existingCognitoId)")
            return existingCognitoId
        }
        
        // If not found, generate new Cognito Identity ID
        let newCognitoId = try await generateNewCognitoIdentity()
        
        // Save the new Cognito ID to Firebase
        try await saveCognitoIdToFirebase(firebaseUserId: firebaseUserId, cognitoId: newCognitoId)
        
        print("Generated new Cognito ID: \(newCognitoId)")
        return newCognitoId
    }
    
    // MARK: - Check Firebase for Existing Cognito ID
    private func getCognitoIdFromFirebase(firebaseUserId: String) async throws -> String? {
        do {
            let document = try await Firestore.firestore().collection("users").document(firebaseUserId).getDocument()
            
            if document.exists,
               let data = document.data(),
               let cognitoId = data["cognitoIdentityId"] as? String {
                return cognitoId
            }
            
            return nil
        } catch {
            print("Error fetching Cognito ID from Firebase: \(error)")
            throw AWSServiceError.firebaseReadError
        }
    }
    
    // MARK: - Generate New Cognito Identity (AWS does this)
     public func generateNewCognitoIdentity() async throws -> String {
        let cognitoConfig = try await CognitoIdentityClient.CognitoIdentityClientConfiguration()
        cognitoConfig.region = region
        let cognitoClient = CognitoIdentityClient(config: cognitoConfig)
        
        let getIdInput = GetIdInput(identityPoolId: identityPoolId)
        let getIdResponse = try await cognitoClient.getId(input: getIdInput)
        
        guard let identityId = getIdResponse.identityId else {
            throw AWSServiceError.failedToGenerateCognitoId
        }
        
        return identityId
    }
    
    // MARK: - Save Cognito ID to Firebase
    private func saveCognitoIdToFirebase(firebaseUserId: String, cognitoId: String) async throws {
        do {
            try await Firestore.firestore().collection("users").document(firebaseUserId).updateData([
                "cognitoIdentityId": cognitoId,
                "cognitoCreatedAt": FieldValue.serverTimestamp()
            ])
        } catch {
            print("Error saving Cognito ID to Firebase: \(error)")
            throw AWSServiceError.firebaseSaveError
        }
    }
    
    // MARK: - Configure S3 Client with Cognito Credentials
    // MARK: - Configure S3 Client with Cognito Credentials
    // MARK: - Configure S3 Client with Cognito Credentials (Environment approach)
    private func configureS3ClientForIdentity(_ identityId: String) async throws -> S3Client {
        let cognitoConfig = try await CognitoIdentityClient.CognitoIdentityClientConfiguration()
        cognitoConfig.region = region
        let cognitoClient = CognitoIdentityClient(config: cognitoConfig)
        
        let getCredentialsInput = GetCredentialsForIdentityInput(identityId: identityId)
        let credentialsResponse = try await cognitoClient.getCredentialsForIdentity(input: getCredentialsInput)
        
        guard let credentials = credentialsResponse.credentials,
              let accessKeyId = credentials.accessKeyId,
              let secret = credentials.secretKey,
              let sessionToken = credentials.sessionToken else {
            throw AWSServiceError.failedToGetCredentials
        }
        
        // Temporarily set environment variables (not ideal but works)
        setenv("AWS_ACCESS_KEY_ID", accessKeyId, 1)
        setenv("AWS_SECRET_ACCESS_KEY", secret, 1)
        setenv("AWS_SESSION_TOKEN", sessionToken, 1)
        
        let s3Config = try await S3Client.S3ClientConfiguration()
        s3Config.region = region
        
        return S3Client(config: s3Config)
    }
    
    // MARK: - Upload Image for Current Firebase User
    func uploadImageToS3(image: UIImage?) async throws -> String {
        guard let currentUser = Auth.auth().currentUser else {
            throw AWSServiceError.userNotAuthenticated
        }
        
        return try await uploadImageForFirebaseUser(image: image, firebaseUserId: currentUser.uid)
    }
    
    // MARK: - Upload Image for Specific Firebase User
    func uploadImageForFirebaseUser(image: UIImage?, firebaseUserId: String) async throws -> String {
        guard let image = image, let imageData = image.jpegData(compressionQuality: 0.7) else {
            throw AWSServiceError.imageConversionFailed
        }
        
        // Get user's Cognito Identity ID (creates one if doesn't exist)
        let cognitoIdentityId = try await getCognitoIdentityForUser(firebaseUserId: firebaseUserId)
        
        // Get temporary AWS credentials for this identity
        let s3Client = try await configureS3ClientForIdentity(cognitoIdentityId)
        
        // Create file path using Cognito Identity ID
        let fileName = "\(UUID().uuidString).jpg"
        let s3Key = "\(cognitoIdentityId)/\(fileName)"
        
        let putObjectInput = PutObjectInput(
            body: .data(imageData),
            bucket: bucketName,
            contentType: "image/jpeg",
            key: s3Key
        )
        
        // Upload to S3 with retry logic
        var retries = 0
        let maxRetries = 3
        let startTime = Date()
        let maxWaitTime: TimeInterval = 300 // 5 minutes
        
        while retries < maxRetries {
            do {
                let _ = try await s3Client.putObject(input: putObjectInput)
                print("Image uploaded successfully to: \(s3Key)")
                
                let imageURL = "https://\(bucketName).s3.\(region).amazonaws.com/\(s3Key)"
                return imageURL
                
            } catch {
                let elapsedTime = Date().timeIntervalSince(startTime)
                if elapsedTime > maxWaitTime {
                    print("Upload failed after \(maxWaitTime) seconds, giving up.")
                    throw AWSServiceError.uploadTimeout
                }
                
                retries += 1
                if retries >= maxRetries {
                    print("Upload failed after \(maxRetries) retries")
                    throw AWSServiceError.uploadFailed(error)
                }
                
                let waitTime = min(pow(2.0, Double(retries)), 60.0)
                print("Upload failed, retrying in \(waitTime) seconds... Attempt \(retries)/\(maxRetries)")
                print("Error: \(error)")
                
                try await Task.sleep(nanoseconds: UInt64(waitTime * 1_000_000_000))
            }
        }
        
        throw AWSServiceError.uploadFailed(NSError(domain: "AWSService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Upload failed after all retries"]))
    }
    
    // MARK: - Get User's Uploaded Images
    func getUserImages(firebaseUserId: String? = nil) async throws -> [String] {
        let userId = firebaseUserId ?? Auth.auth().currentUser?.uid
        guard let userId = userId else {
            throw AWSServiceError.userNotAuthenticated
        }
        
        let cognitoIdentityId = try await getCognitoIdentityForUser(firebaseUserId: userId)
        let s3Client = try await configureS3ClientForIdentity(cognitoIdentityId)
        
        let listObjectsInput = ListObjectsV2Input(
            bucket: bucketName,
            prefix: "\(cognitoIdentityId)/"
        )
        
        do {
            let response = try await s3Client.listObjectsV2(input: listObjectsInput)
            
            var imageURLs: [String] = []
            if let contents = response.contents {
                for object in contents {
                    if let key = object.key {
                        let imageURL = "https://\(bucketName).s3.\(region).amazonaws.com/\(key)"
                        imageURLs.append(imageURL)
                    }
                }
            }
            
            return imageURLs
        } catch {
            throw AWSServiceError.listObjectsFailed(error)
        }
    }
    
    // MARK: - Get Image from S3 URL
    func getImageFromS3(imageURL: String) async throws -> UIImage {
        guard let url = URL(string: imageURL) else {
            throw AWSServiceError.invalidURL
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                throw AWSServiceError.networkError
            }
            
            guard let image = UIImage(data: data) else {
                throw AWSServiceError.imageConversionFailed
            }
            
            return image
        } catch {
            throw AWSServiceError.networkError
        }
    }
    
    // MARK: - Delete User Image
    func deleteImage(imageURL: String, firebaseUserId: String? = nil) async throws {
        let userId = firebaseUserId ?? Auth.auth().currentUser?.uid
        guard let userId = userId else {
            throw AWSServiceError.userNotAuthenticated
        }
        
        // Extract key from URL
        guard let urlComponents = URL(string: imageURL)?.pathComponents,
              urlComponents.count >= 2 else {
            throw AWSServiceError.invalidURL
        }
        
        // Reconstruct the S3 key from URL
        let key = urlComponents.dropFirst().joined(separator: "/")
        
        let cognitoIdentityId = try await getCognitoIdentityForUser(firebaseUserId: userId)
        let s3Client = try await configureS3ClientForIdentity(cognitoIdentityId)
        
        let deleteObjectInput = DeleteObjectInput(
            bucket: bucketName,
            key: key
        )
        
        do {
            let _ = try await s3Client.deleteObject(input: deleteObjectInput)
            print("Image deleted successfully: \(key)")
        } catch {
            throw AWSServiceError.deleteFailed(error)
        }
    }
    
    // MARK: - Legacy function for backward compatibility
    func uploadImageToS3(image: UIImage?, bucketName: String) async throws -> String {
        print("Warning: Using legacy uploadImageToS3 function. Consider using the new Cognito-integrated version.")
        return try await uploadImageToS3(image: image)
    }
    
    // MARK: - Get Bucket Names (for debugging)
    func getBucketNames() async throws -> [String] {
        guard let currentUser = Auth.auth().currentUser else {
            throw AWSServiceError.userNotAuthenticated
        }
        
        let cognitoIdentityId = try await getCognitoIdentityForUser(firebaseUserId: currentUser.uid)
        let client = try await configureS3ClientForIdentity(cognitoIdentityId)
        
        let pages = client.listBucketsPaginated(
            input: ListBucketsInput(maxBuckets: 10)
        )
        
        var bucketNames: [String] = []
        
        do {
            for try await page in pages {
                guard let buckets = page.buckets else {
                    print("Error: no buckets returned.")
                    continue
                }
                for bucket in buckets {
                    bucketNames.append(bucket.name ?? "<unknown>")
                }
            }
            return bucketNames
        } catch {
            print("ERROR: listBuckets:", dump(error))
            throw error
        }
    }
}

// MARK: - Error Handling
enum AWSServiceError: Error, LocalizedError {
    case firebaseReadError
    case firebaseSaveError
    case failedToGenerateCognitoId
    case failedToGetCredentials
    case imageConversionFailed
    case uploadFailed(Error)
    case uploadTimeout
    case listObjectsFailed(Error)
    case deleteFailed(Error)
    case invalidURL
    case networkError
    case userNotAuthenticated
    
    var errorDescription: String? {
        switch self {
        case .firebaseReadError:
            return "Failed to read from Firebase"
        case .firebaseSaveError:
            return "Failed to save to Firebase"
        case .failedToGenerateCognitoId:
            return "Failed to generate Cognito Identity ID"
        case .failedToGetCredentials:
            return "Failed to get AWS credentials"
        case .imageConversionFailed:
            return "Failed to convert image to data"
        case .uploadFailed(let error):
            return "Upload failed: \(error.localizedDescription)"
        case .uploadTimeout:
            return "Upload timed out"
        case .listObjectsFailed(let error):
            return "Failed to list objects: \(error.localizedDescription)"
        case .deleteFailed(let error):
            return "Failed to delete image: \(error.localizedDescription)"
        case .invalidURL:
            return "Invalid URL provided"
        case .networkError:
            return "Network error occurred"
        case .userNotAuthenticated:
            return "User not authenticated"
        }
    }
}
