param([string]$ServerName, [string]$ProjectFilePath)

#$servername = "MHEDW-DEV"
#$ProjectFilePath = "C:\Users\dnwemeh\Documents\RC004Dev\StagingHistory\ETL\SalesForceStagingHistoryLoad\bin\Development\SalesForceStagingHistoryLoad.ispac"

$SSISCatalog     = "SSISDB"
$CatalogPwd      = "putyourpasswordhere"
$ProjectName     = "SalesForceStagingHistoryLoad"
$FolderName      = "StagingHistory"
$EnvironmentName = "SalesForceStagingHistoryLoad"


#Function to Contol Errors (Error-Handling) while deploying project 
function ExitWithCode 
{ 
    param 
    ( 
        $exitcode 
    )
    $host.SetShouldExit($exitcode) 
}



#Dynamically configure the temp and archive file paths depending on server name
switch ($ServerName)
       {
              "MY-DEV" 
                           {
                                $NotificationEmail = "darlington.nwemeh@me.com"; break                
                           }
              "MY-QA" 
                           {
                                $NotificationEmail = "Peter.Su@me.com"; break  
                           }
              "MY-UAT" 
                           {
                                $NotificationEmail = "BISupport@me.com"; break  
                           }
              "MYEDW"      
                           {
                                $NotificationEmail = "BISupport@me.com"; break  
                           }
              default      
                           {     
                                $NotificationEmail = "BISupport@me.com"; break  
                           }
       }



#Load Assembly for SQLServer Management Objects (SMO)
[System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.SMO')

$svr = New-Object('Microsoft.SqlServer.Management.Smo.Server')

#region SSIS Setup

    # Load the IntegrationServices Assembly
    [Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.Management.IntegrationServices")

    # Store the IntegrationServices Assembly namespace to avoid typing it every time
    $ISNamespace = "Microsoft.SqlServer.Management.IntegrationServices"

#Begin Try (Error-Handling)
try
{


    Write-Host "Connecting to server"  $ServerName " ..."

    #create a connection to the server
    $sqlConnectionString = "Data Source=$ServerName;Initial Catalog=master;Integrated Security=SSPI;"
    $sqlConnection = New-Object System.Data.SqlClient.SqlConnection $sqlConnectionString

    $integrationServices = New-Object "$ISNamespace.IntegrationServices" $sqlConnection


    #creating new catalog if ssisdb catalog doesn't exist 
    if ($integrationservices.catalogs.count -lt 1) 
    {
           write-host "creating new ssisdb catalog ..."            
           $cat = new-object $isnamespace".catalog" ($integrationservices, "ssisdb", "#password1")            
           $cat.create()  
    }

    $catalog = $integrationServices.Catalogs["SSISDB"]

    #creating new project folder if folder doesn't exist
    if (!$catalog.folders[$foldername])
    {
           write-host "creating " $foldername " folder ..."
           $folder = new-object $isnamespace".catalogfolder" ($catalog, $foldername, "")
           $folder.create()
    }

#endregion

$folder = $catalog.Folders[$foldername]

 #region deploying projects

    if ($folder.Projects.Item($ProjectName))
    {
        $folder.Projects.Item($ProjectName).Drop()
    }

     Write-Host "Deploying Projects ..."
    [byte[]] $projectFile = [System.IO.File]::ReadAllBytes($ProjectFilePath)
    $folder.DeployProject($ProjectName, $projectFile)
    #endregion

#region Creating Environment for Incremental Load 

    $environment = $folder.Environments[$EnvironmentName]

    if ($environment)
    {
        Write-Host "Dropping environment ..." 
        $environment.Drop()
    }

    write-host "creating " $environmentname " environment ..."
    $environment = New-Object $ISNamespace".EnvironmentInfo" ($folder, $EnvironmentName, $EnvironmentName)
    $environment.create()

    #Create project reference
    $project = $folder.Projects[$ProjectName]
    $ref = $project.References[$EnvironmentName, $folder.Name]

    if (!$ref)
    {
           Write-Host "Adding Project Reference ..."
           $project.References.Add($EnvironmentName, $folder.Name)
           $project.Alter()
    }

    #Add variable to environment
    Write-Host "Adding environment variables ..." 
    $environment.Variables.Add(“eAuditDatabase”, [System.TypeCode]::String,"ETLAudit", $false,"Audit Database name")
    $environment.Variables.Add(“eAuditServer”, [System.TypeCode]::String, $ServerName, $false,"Audit Server name")
    $environment.Variables.Add(“eBufferTempStoragePath”, [System.TypeCode]::String, "", $false,"Buffer Temp Storage Path")
    $environment.Variables.Add(“eTargetDatabase”, [System.TypeCode]::String, "StagingHistory", $false, "Target Database")
    $environment.Variables.Add(“eTargetServer”, [System.TypeCode]::String, $ServerName, $false, "Target Server name")
    $environment.Variables.Add(“eSourceDatabase”, [System.TypeCode]::String, "PreStaging", $false, "Source Database name")
    $environment.Variables.Add(“eSourceServer”, [System.TypeCode]::String, $ServerName,$false, "Source Server name") ##############
    #$environment.Variables.Add(“eSalesforceUserName”, [System.TypeCode]::String,"dataintegration@millenniumhealth.com.staging", $false,"Salesforce.com UserName")
	$environment.Variables.Add("eNotificationEmail", [System.TypeCode]::String, $NotificationEmail, $false,"Notification Email address")
	$environment.Variables.Add(“eDebugMode”, [System.TypeCode]::Boolean, 1, $false,"Debug Mode")
    $environment.Alter()

#endregion

#region  Project & Package Level Parameter Mapping
    Write-Host "Adding project reference ..."  
    $project.Parameters["pAuditDatabase"].Set([Microsoft.SqlServer.Management.IntegrationServices.ParameterInfo+ParameterValueType]::Referenced, "eAuditDatabase")
    $project.Parameters["pAuditServer"].Set([Microsoft.SqlServer.Management.IntegrationServices.ParameterInfo+ParameterValueType]::Referenced, "eAuditServer")   
    #$project.Parameters["pBLOBTempStoragePath"].Set([Microsoft.SqlServer.Management.IntegrationServices.ParameterInfo+ParameterValueType]::Referenced, "eBLOBTempStoragePath")
    #$project.Parameters["pBufferTempStoragePath"].Set([Microsoft.SqlServer.Management.IntegrationServices.ParameterInfo+ParameterValueType]::Referenced, "eBufferTempStoragePath")
    #$project.Parameters["pSalesforceUserName"].Set([Microsoft.SqlServer.Management.IntegrationServices.ParameterInfo+ParameterValueType]::Referenced, "eSalesforceUserName") 
    $project.Parameters["pTargetDatabase"].Set([Microsoft.SqlServer.Management.IntegrationServices.ParameterInfo+ParameterValueType]::Referenced,"eTargetDatabase")
    $project.Parameters["pTargetServer"].Set([Microsoft.SqlServer.Management.IntegrationServices.ParameterInfo+ParameterValueType]::Referenced,"eTargetServer")
    $project.Parameters["pSourceDatabase"].Set([Microsoft.SqlServer.Management.IntegrationServices.ParameterInfo+ParameterValueType]::Referenced, "eSourceDatabase")
    $project.Parameters["pSourceServer"].Set([Microsoft.SqlServer.Management.IntegrationServices.ParameterInfo+ParameterValueType]::Referenced,"eSourceServer")
    $project.Parameters["pNotificationEmail"].Set([Microsoft.SqlServer.Management.IntegrationServices.ParameterInfo+ParameterValueType]::Referenced, "eNotificationEmail") 
	$project.Parameters["pDebugMode"].Set([Microsoft.SqlServer.Management.IntegrationServices.ParameterInfo+ParameterValueType]::Referenced, "eDebugMode")   
    $project.Alter() 
	

	Write-Host "Adding package reference ...LoadTablePreStagingSalesForceMLISAccountCStagingHistorySalesForceMLISAccountCInitIncr"      
	$package = $project.Packages["LoadTablePreStagingSalesForceMLISAccountCStagingHistorySalesForceMLISAccountCInitIncr.dtsx"]    
    $package.Parameters["paramSSISOpsNF_To"].Set([Microsoft.SqlServer.Management.IntegrationServices.ParameterInfo+ParameterValueType]::Referenced, "eNotificationEmail") 
    $package.Alter() 


	Write-Host "Adding package reference ...LoadTablePreStagingSalesForceLSAAssignmentCStagingHistorySalesForceLSAAssignmentCInitIncr"      
	$package = $project.Packages["LoadTablePreStagingSalesForceLSAAssignmentCStagingHistorySalesForceLSAAssignmentCInitIncr.dtsx"]    
    $package.Parameters["paramSSISOpsNF_To"].Set([Microsoft.SqlServer.Management.IntegrationServices.ParameterInfo+ParameterValueType]::Referenced, "eNotificationEmail") 
    $package.Alter() 
  

	Write-Host "Adding package reference ...LoadTablePreStagingSalesForceContactStagingHistorySalesForceContactInitIncr"      
	$package = $project.Packages["LoadTablePreStagingSalesForceContactStagingHistorySalesForceContactInitIncr.dtsx"]    
    $package.Parameters["paramSSISOpsNF_To"].Set([Microsoft.SqlServer.Management.IntegrationServices.ParameterInfo+ParameterValueType]::Referenced, "eNotificationEmail") 
    $package.Alter()  
   
   
	Write-Host "Adding package reference ...StagingHistorySalesForceMasterPackage"      
	$package = $project.Packages["StagingHistorySalesForceMasterPackage.dtsx"]    
    $package.Parameters["paramSSISOpsNF_To"].Set([Microsoft.SqlServer.Management.IntegrationServices.ParameterInfo+ParameterValueType]::Referenced, "eNotificationEmail") 
    $package.Alter() 
  


#endregion

#End Catch
}
catch
{
    $err = $Error[0].Exception ; 
    write-host "--> Deployment Error caught: " $err.Message ; 
    ExitWithCode 1
}

