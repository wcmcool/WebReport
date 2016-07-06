#
# GetADUsersInformation.ps1
#

# Import modules
try
{
	Import-Module .\Modules\ModReadConfig\ModReadConfig.psm1 -ErrorAction Stop
	Import-Module .\Modules\ModOutputLogs\ModOutputLogs.psm1 -ErrorAction Stop
	Import-Module .\Modules\ModCredential\ModCredential.psm1 -ErrorAction Stop
	Import-Module .\Modules\ModInputDatabase\ModInputDatabase.psm1 -ErrorAction Stop
}
catch
{
	Out-File -InputObject "$(Get-Date) from GetADUsersInformation.ps1 Import-Module fail ,check modules" -FilePath .\GetADUsersInformation.log
}


# Get AD computer name
$ADComputerNameKey="ADComputerName"
$ADComputerName=Fun_ReadConfig $ADComputerNameKey

# Get AD credential
$ADUserNameKey="ADUserName"
$ADUserName=Fun_ReadConfig $ADUserNameKey

$ADPasswordKey="ADPassword"
$ADPassword=Fun_ReadConfig $ADPasswordKey

$ADCredential=Fun_Credential $ADUserName $ADPassword

# Database serverinstance
$SQLServerInstanceKey="SqlServerIntance"
$SQLServerInstance=Fun_ReadConfig $SQLServerInstanceKey

# Database username
$SQLUserNameKey="SqlUserName"
$SQLUserName=Fun_ReadConfig $SQLUserNameKey

# Database password need to convert to securestring
$SQLPasswordKey="SqlPassword"
$SQLEncryptPassword=Fun_ReadConfig $SQLPasswordKey

# Call from
$CallFrom="GetADusersInformation"

try
{
	$SecureStringSQLPassword=ConvertTo-SecureString -String $SQLEncryptPassword -ErrorAction Stop
}
catch
{
	$LogMessage="Log from GetADUsersInfomation.ps1 ����ת��Ϊ��ȫ�ַ����� ����ȷ�������ļ�Config�Ƿ��ڱ������ɣ�����������GenerateConfig.ps1�������������ļ�Config"
	Fun_OutputLogs $LogMessage
	$LogMessage=$_.Exception.Message
	Fun_OutputLogs $LogMessage
}

try
{
	$SQLPassword=[System.Runtime.InteropServices.Marshal]::PtrToStringUni([System.Runtime.InteropServices.Marshal]::SecureStringToGlobalAllocUnicode($SecureStringSQLPassword))
}
catch
{
	$LogMessage="Log from GetADUsersInfomation.ps1 ��ȫ�ַ�ת��Ϊ���Ĵ��� ����ȷ�������ļ�Config�Ƿ��ڱ������ɣ�����������GenerateConfig.ps1�������������ļ�Config"
	Fun_OutputLogs $LogMessage
	$LogMessage=$_.Exception.Message
	Fun_OutputLogs $LogMessage
}

# Get $ADGetGroups
$ADGetGroupsScriptBlock=
{
	Import-Module ActiveDirectory;
	Get-ADGroup -Filter *
}

try
{
	$ADGroups=Invoke-Command -ComputerName $ADComputerName -Credential $ADCredential -ScriptBlock $ADGetGroupsScriptBlock
}
catch
{
	$LogMessage="Log from GetADUsersInfomation.ps1 Invoke-command Get-ADGroup fail ,��ȡAD�û���ʧ��"
	Fun_OutputLogs $LogMessage
}

# Get users
foreach ($GroupLine in $ADGroups)
{
	$ADGetGroupsScriptBlock=
	{
		Import-Module ActiveDirectory;
		Get-ADGroupMember $GroupLine
	}
	try
	{
		$ADUsers=Invoke-Command -ComputerName $ADComputerName -Credential $ADCredential -ScriptBlock $ADGetUsersScriptBlock
	}
	catch
	{
		$LogMessage="Log from GetADUsersInfomation.ps1 Invoke-command Get-ADGroupMenber fail ,��ȡAD�û�ʧ��"
		Fun_OutputLogs $LogMessage
	}

	# Output to database
	foreach ($ADUserLine in $ADUsers)
	{
		# Data veriables
		$ADUsername=$ADUserLine.SamAccountName
		$ADUserFullname=$ADUserLine.name
		$ADUid=$ADUserLine.SID
		$ADDepartment=$GroupLine.name
		$ADDepartmentGID=$GroupLine.SID
		$GetTime=Get-Date

		# Sql query statements
		$Query="
		use WebReport;
		insert into dbo.DepartmentsUsers
		(
			ID,
			UserName,
			FullUserName,
			UID,
			Department,
			GID,
			GetTime
		)
		values
		(
			'$ADUsername',
			'$ADUserFullname',
			'$ADUid',
			'$ADDepartment',
			'$ADDepartmentGID',
			'$GetTime'
		)"

		# Output AD data to database
		Fun_InputDatabase $Query $SQLServerInstance $SQLUserName $SQLPassword $CallFrom
	}
}