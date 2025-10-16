### 🔐 Azure Key Vault Managed Identity Lab  
**Terraform + .NET 8 on Linux App Service**

This project demonstrates the secure deployment of a .NET 8 API to Azure App Service (Linux), using a **System-Assigned Managed Identity** to retrieve secrets from **Azure Key Vault**. All infrastructure is defined in **Terraform**, and the application is deployed via CLI automation.

## 🚀 Project Goal & Solution

The objective was to build a secure, serverless application where:
- 🔒 Secrets are never stored in code or config files
- ⚙️ Infrastructure is reproducible and declarative
- 🧠 Identity-based access replaces connection strings

| Component         | Status               | Key Configuration                                                                 |
|------------------|----------------------|------------------------------------------------------------------------------------|
| Infrastructure    | ✅ Deployed via Terraform | App Service (`webapp-lewis`), Key Vault (`kv-lewis`), Private Endpoint, DNS Zone |
| Authentication    | ✅ Securely Configured    | System-Assigned Managed Identity + `Key Vault Secrets User` RBAC Role             |
| Runtime Stack     | ✅ Fixed & Verified       | Linux with `.NET 8.0` (forced via CLI to override Oryx misdetection)              |
| Application Proof | ✅ Functional             | Secret retrieved at runtime and exposed via `/config` endpoint                    |

## 🌐 Live Application Endpoints

| Endpoint     | Purpose                  | Expected Output                                      |
|--------------|--------------------------|------------------------------------------------------|
| `/`          | App Status Check         | `"Key Vault Lab Application is Running..."`          |
| `/config`    | Secret Verification      | JSON containing the `DbConnectionString` from Key Vault |

## 🛠️ Infrastructure & Application Deployment

### I. Infrastructure Deployment (Terraform)

All core resources are defined in `main.tf` and deployed using standard commands:


terraform init
terraform apply -auto-approve

⏳ Note: A time delay of 5–10 minutes is often required after deployment for the Managed Identity RBAC role (Key Vault Secrets User) to fully propagate before the application can authenticate.

# II. Application Deployment (Fixing the Environment)
The App Service environment required manual intervention to stabilize the .NET Linux stack and successfully deploy the code.

🔧 Fix the Runtime Stack (Critical Step)
The Linux stack often defaults or conflicts with Terraform settings. This command forces the correct runtime:

bash
az webapp config set --resource-group "KeyVaultLab-RG" --name "webapp-lewis" --startup-file "" --linux-fx-version "DOTNETCORE|8.0"

## 📦 Publish and Package the Code
To avoid the 403 (runtime mismatch) and 502 (missing startup DLL) errors, the publish and ZIP steps must be exact:

bash
# 1. Publish the application
dotnet publish --configuration Release -o ./publish 

# 2. Package the *contents* of the publish directory (crucial for Oryx)
cd publish
zip -r ../publish_final.zip ./*
cd ..


# 🚀 Deploy the Application Code
bash
az webapp deployment source config-zip --resource-group "KeyVaultLab-RG" --name "webapp-lewis" --src ./publish_final.zip

# 🔁 Restart the Web App
bash
az webapp restart --resource-group "KeyVaultLab-RG" --name "webapp-lewis"

# 🧠 Key Code Logic (Program.cs)
The secure retrieval happens during application startup using the Azure.Identity and Azure.Security.KeyVault.Secrets libraries:

csharp
var credential = new DefaultAzureCredential();
var client = new SecretClient(kvUri, credential);

try
{
    KeyVaultSecret secret = await client.GetSecretAsync("DbConnectionString");
    dbConnectionString = secret.Value;
    Console.WriteLine($"Successfully retrieved secret: {secret.Name}");
}
catch (Exception ex)
{
    Console.WriteLine($"Error retrieving secret: {ex.Message}");
}

app.MapGet("/", () => Results.Ok("Key Vault Lab Application is Running. Access /config for details."));

# 📌 Lessons Learned & Troubleshooting Wins
✅ Runtime mismatch (403 errors) resolved by forcing DOTNETCORE|8.0 and clearing Oryx startup command

✅ Missing DLLs (502 errors) resolved by publishing and zipping the correct output directory

✅ RBAC propagation delays handled with retry logic and logging

✅ Private Endpoint + DNS Zone ensure Key Vault is accessed securely over VNet

# 🧰 Next Steps (Optional Enhancements)
Add CI/CD pipeline via Azure DevOps or GitHub Actions

Add health check and logging endpoints

Extend to use Azure SQL or Cosmos DB with managed identity