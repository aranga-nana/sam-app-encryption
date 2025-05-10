import { SNSEvent, Context } from "aws-lambda";
import { KMSClient, DecryptCommand } from "@aws-sdk/client-kms";

/**
 * A Lambda function that logs the payload received from SNS.
 */
export const handler = async (event: SNSEvent, context: Context): Promise<void> => {
    const kmsClient = new KMSClient({ region: process.env.AWS_REGION });
    const encryptedSecret = process.env.AUTH_SECRET; // Encrypted value from environment variables

    if (!encryptedSecret) {
        console.error("AUTH_SECRET is not set in environment variables.");
        return;
    }

    try {
        // Decrypt the secret
        const decryptCommand = new DecryptCommand({
            CiphertextBlob: Buffer.from(encryptedSecret, "base64"),
        });
        const decryptedSecret = await kmsClient.send(decryptCommand);

        const secretValue = Buffer.from(decryptedSecret.Plaintext as Uint8Array).toString("utf-8");
        console.log("Decrypted secret:", secretValue);

        // Log the SNS event
        console.info(event);
        console.log("Received SNS event:", JSON.stringify(event, null, 2));
    } catch (error) {
        console.error("Failed to decrypt the secret:", error);
    }
};