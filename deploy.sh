# This file can be used to:
# 1. deploy the Terraform infrastructure
# 2. build the web app code as latest code
# 3. zip up the web app code as latest code
# 4. deploy the web app code to the Azure Web App


# Step 1: Deploy the Terraform infrastructure
echo "Deploying Terraform infrastructure..."
terraform init
terraform apply -auto-approve
echo "Terraform infrastructure deployed."

# Step 2: Build the web app code as latest code
echo "Building web app code..."
cd WebApp
dotnet publish -c Release -o ./publish
echo "Web app code built."

# Step 3: Zip up the web app code as latest code
echo "Zipping up web app code..."
cd publish
zip -r ../webapp.zip .
cd ..
echo "Web app code zipped to webapp.zip"

# Step 4: Deploy the web app code to the Azure Web App 
echo "Deploying web app code to Azure Web App..."
# az login
az webapp deployment source config-zip --resource-group keyvaultlab-rg --name webapp-lewis --src webapp.zip
echo "Deployment complete."

###############
# CRUCIAL: Step 5: Force stack to .NET 8 
az webapp config set --resource-group "KeyVaultLab-RG" --name "webapp-lewis" --startup-file "" --linux-fx-version "DOTNETCORE|8.0"
###############

# Step 6: Web app restart to ensure it picks up the new code
echo "Restarting web app to pick up new code..."
az webapp restart --resource-group keyvaultlab-rg --name webapp-lewis
echo "Web app restarted."
echo "All steps completed. - view the web app at https://webapp-lewis.azurewebsites.net"