# Azure Key Vault Managed Identity Lab (Terraform & .NET 8 on Linux)
This project documents the successful deployment of a secure .NET 8 API to an Azure App Service on Linux. The application retrieves a sensitive configuration value (a database connection string) from Azure Key Vault using a System-Assigned Managed Identity. All infrastructure is defined and managed using Terraform.

# 🚀 Project Goal & Solution
The objective was to create a secure, serverless application where the code never directly stores secrets.

Component	Status	Key Configuration
Infrastructure	Deployed via Terraform	Azure App Service (webapp-lewis), Key Vault (kv-lewis)
Authentication	Securely Configured	System-Assigned Managed Identity + Key Vault Secrets User RBAC Role
Runtime Stack	Fixed & Verified	Linux with .NET 8.0
Application Proof	Functional	Code retrieves the secret and exposes it on a dedicated endpoint.

🔗 Live Application Endpoints
The final, running application can be verified at the following URLs:

Endpoint	Purpose	Expected Output
Root Path	Application Status Check	"Key Vault Lab Application is Running..."
/config API	Secret Verification	JSON containing the DbConnectionString from Key Vault.

🛠️ Infrastructure and Application Steps
I. Infrastructure Deployment (Terraform)
All core resources are defined in main.tf and deployed using standard commands:

Initialize Terraform:

Bash

terraform init
Deploy all resources (including Key Vault and App Service):

Bash

terraform apply
Note: A time delay of 5-10 minutes is often required after deployment for the Managed Identity RBAC role (Key Vault Secrets User) to fully propagate before the application can authenticate.

II. Application Deployment (Fixing the Environment)
The App Service environment required manual intervention to stabilize the .NET Linux stack and successfully deploy the code.

Fix the Runtime Stack (Critical Step):
The Linux stack often defaults or conflicts with Terraform settings. This command forces the correct runtime:

Bash

az webapp config set \
  --resource-group "KeyVaultLab-RG" \
  --name "webapp-lewis" \
  --linux-fx-version "DOTNETCORE|8.0"
Publish and Package the Code:
To avoid the 404 (missing root endpoint) and the 502 (missing startup DLL) errors, the publish and ZIP steps must be exact:

Bash

# 1. Publish the application
dotnet publish --configuration Release -o ./publish 

# 2. Package the *contents* of the publish directory (crucial for Oryx)
cd publish
zip -r ../publish_final.zip ./*
cd ..
Deploy the Application Code:

Bash

az webapp deploy --resource-group "KeyVaultLab-RG" --name "webapp-lewis" --src-path ./publish_final.zip --type zip
📝 Key Code Logic (Program.cs)
The secure retrieval happens during application startup using the Azure.Identity and Azure.Security.KeyVault.Secrets libraries:

C#

// Use the Managed Identity of the App Service
var credential = new DefaultAzureCredential();
var client = new SecretClient(kvUri, credential);

try
{
    // Retrieve the secret by name
    KeyVaultSecret secret = await client.GetSecretAsync("DbConnectionString");
    dbConnectionString = secret.Value;
    // Log success message (verified in the Azure Log Stream)
    Console.WriteLine($"Successfully retrieved secret: {secret.Name}"); 
}
catch (Exception ex)
{
    // Fallback if RBAC or network access fails
    Console.WriteLine($"Error retrieving secret: {ex.Message}");
}

// Final routing to fix the 404 error
app.MapGet("/", () => Results.Ok("Key Vault Lab Application is Running. Access /config for details."));