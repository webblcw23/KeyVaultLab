using Azure.Identity;
using Azure.Security.KeyVault.Secrets;

var builder = WebApplication.CreateBuilder(args);

// --- SECURE KEY VAULT RETRIEVAL LOGIC STARTS HERE ---
const string keyVaultName = "kv-lewis";
var kvUri = new Uri($"https://{keyVaultName}.vault.azure.net/");

// DefaultAzureCredential automatically uses the Web App's Managed Identity in Azure.
var credential = new DefaultAzureCredential();
var client = new SecretClient(kvUri, credential);

// Set a safe default value. This is the value used if authentication/access fails.
string dbConnectionString = "CONNECTION STRING: Access Denied or Local Test Failure";

try
{
    // Attempt to retrieve the secret from the Key Vault
    KeyVaultSecret secret = await client.GetSecretAsync("DbConnectionString");
    dbConnectionString = secret.Value;
    Console.WriteLine($"Successfully retrieved secret: {secret.Name}");
}
catch (Exception ex)
{
    Console.WriteLine($"Error retrieving secret. Falling back to default: {ex.Message}");
    // The placeholder value is retained, which is better than crashing the app.
}
// --- SECURE KEY VAULT RETRIEVAL LOGIC ENDS HERE ---

// Add services to the container (Required for Swagger/OpenAPI).
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();

var app = builder.Build();

// Configure the HTTP request pipeline.
app.UseSwagger();
app.UseSwaggerUI();

app.UseHttpsRedirection();

// Define the API endpoint to display the secret value
app.MapGet("/", () => Results.Ok("Key Vault Lab Application is Running. Access /config for details.")); 
app.MapGet("/config", () =>
{
    // This returns the securely retrieved secret in Azure, or the placeholder elsewhere.
    return Results.Ok(new { DbConnectionString = dbConnectionString });
})
.WithName("GetConfiguration");

app.Run();

// Commands to deploy to azure's web app
// Esnure webapp code is published in a ready format
// dotnet publish --configuration Release -o ./publish 
// manually zip the publish folder to publish.zip
// az login
// az webapp deploy --resource-group "KeyVaultLab-RG" --name "webapp-lewis" --src-path ./publish_correct.zip --type zip

// Verify deployment
// az webapp show --resource-group KeyVaultLab-RG --name webapp-lewis --query defaultHostName --output tsv

