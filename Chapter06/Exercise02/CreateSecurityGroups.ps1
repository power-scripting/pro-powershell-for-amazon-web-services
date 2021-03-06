
#This script will create security groups for a web application running on windows with a SQL back end and domain controller

param
(
    [string][parameter(mandatory=$true)]$VPCID
)

$DomainMembersGroupId = New-EC2SecurityGroup -GroupName 'DomainMembers' -GroupDescription "Domain Members" -VpcId $VPCID
$DomainControllersGroupId = New-EC2SecurityGroup -GroupName 'DomainControllers' -GroupDescription "Domain controllers" -VpcId $VPCID
$WebServersGroupId = New-EC2SecurityGroup -GroupName 'WebServers' -GroupDescription "Web servers" -VpcId $VPCID
$SQLServersGroupId = New-EC2SecurityGroup -GroupName 'SQLServers' -GroupDescription "SQL Servers" -VpcId $VPCID

#First, the Web instances must allow HTTP/S from the internet
$HTTPRule = New-Object Amazon.EC2.Model.IpPermission
$HTTPRule.IpProtocol='tcp'
$HTTPRule.FromPort = 80
$HTTPRule.ToPort = 80
$HTTPRule.IpRanges = '0.0.0.0/0'
$HTTPSRule = New-Object Amazon.EC2.Model.IpPermission
$HTTPSRule.IpProtocol='tcp'
$HTTPSRule.FromPort = 443
$HTTPSRule.ToPort = 443
$HTTPSRule.IpRanges = '0.0.0.0/0'
Grant-EC2SecurityGroupIngress -GroupId $WebServersGroupId -IpPermissions $HTTPRule, $HTTPSRule

#Next, SQL instances must allow requests from the instances in the web server group                      
$WebGroup = New-Object Amazon.EC2.Model.UserIdGroupPair 
$WebGroup.GroupId = $WebServersGroupId
$SQLRule = New-Object Amazon.EC2.Model.IpPermission
$SQLRule.IpProtocol='tcp'
$SQLRule.FromPort = 1433
$SQLRule.ToPort = 1433
$SQLRule.UserIdGroupPair = $WebGroup
$NetBIOSRule = New-Object Amazon.EC2.Model.IpPermission
$NetBIOSRule.IpProtocol='tcp'
$NetBIOSRule.FromPort = 139
$NetBIOSRule.ToPort = 139
$NetBIOSRule.UserIdGroupPair = $WebGroup
$SMBRule = New-Object Amazon.EC2.Model.IpPermission
$SMBRule.IpProtocol='tcp'
$SMBRule.FromPort = 445
$SMBRule.ToPort = 445
$SMBRule.UserIdGroupPair = $WebGroup
Grant-EC2SecurityGroupIngress -GroupId $SQLServersGroupId -IpPermissions $SQLRule, $NetBIOSRule, $SMBRule

#Now, create a group for all domain members.  
#Domain members must allow ping from the domain controller
$DCGroup = New-Object Amazon.EC2.Model.UserIdGroupPair 
$DCGroup.GroupId = $DomainControllersGroupId
$PingRule = New-Object Amazon.EC2.Model.IpPermission
$PingRule.IpProtocol='icmp'
$PingRule.FromPort = 8
$PingRule.ToPort = -1
$PingRule.UserIdGroupPair = $DCGroup
Grant-EC2SecurityGroupIngress -GroupId $DomainMembersGroupId -IpPermissions $PingRule

#Domain controllers must allow ping from the domain members 
$DMGroup = New-Object Amazon.EC2.Model.UserIdGroupPair 
$DMGroup.GroupId = $DomainMembersGroupId
$PingRule = New-Object Amazon.EC2.Model.IpPermission
$PingRule.IpProtocol='icmp'
$PingRule.FromPort = 8
$PingRule.ToPort = -1
$PingRule.UserIdGroupPair = $DMGroup
Grant-EC2SecurityGroupIngress -GroupId $DomainControllersGroupId -IpPermissions $PingRule

#Domain controllers must be able to communicate with other domain controllers 
$AllRule = New-Object Amazon.EC2.Model.IpPermission
$AllRule.IpProtocol='-1'
$AllRule.UserIdGroupPair = $DCGroup
Grant-EC2SecurityGroupIngress -GroupId $DomainControllersGroupId -IpPermissions $AllRule

#Domain controllers must allow numerous TCP protocols from domain members
$DNSRule = New-Object Amazon.EC2.Model.IpPermission
$DNSRule.IpProtocol='tcp'
$DNSRule.FromPort = 53
$DNSRule.ToPort = 53
$DNSRule.UserIdGroupPair = $DMGroup
$KerberosRule = New-Object Amazon.EC2.Model.IpPermission
$KerberosRule.IpProtocol='tcp'
$KerberosRule.FromPort = 88
$KerberosRule.ToPort = 88
$KerberosRule.UserIdGroupPair = $DMGroup
$NetBIOSRule = New-Object Amazon.EC2.Model.IpPermission
$NetBIOSRule.IpProtocol='tcp'
$NetBIOSRule.FromPort = 137
$NetBIOSRule.ToPort = 139
$NetBIOSRule.UserIdGroupPair = $DMGroup
$RPCRule = New-Object Amazon.EC2.Model.IpPermission
$RPCRule.IpProtocol='tcp'
$RPCRule.FromPort = 135
$RPCRule.ToPort = 135
$RPCRule.UserIdGroupPair = $DMGroup
$LDAPRule = New-Object Amazon.EC2.Model.IpPermission
$LDAPRule.IpProtocol='tcp'
$LDAPRule.FromPort = 389
$LDAPRule.ToPort = 389
$LDAPRule.UserIdGroupPair = $DMGroup
$SMBRule = New-Object Amazon.EC2.Model.IpPermission
$SMBRule.IpProtocol='tcp'
$SMBRule.FromPort = 445
$SMBRule.ToPort = 445
$SMBRule.UserIdGroupPair = $DMGroup
$PasswordRule = New-Object Amazon.EC2.Model.IpPermission
$PasswordRule.IpProtocol='tcp'
$PasswordRule.FromPort = 464
$PasswordRule.ToPort = 464
$PasswordRule.UserIdGroupPair = $DMGroup
$LDAPSRule = New-Object Amazon.EC2.Model.IpPermission
$LDAPSRule.IpProtocol='tcp'
$LDAPSRule.FromPort = 636
$LDAPSRule.ToPort = 636
$LDAPSRule.UserIdGroupPair = $DMGroup
$ADRule = New-Object Amazon.EC2.Model.IpPermission
$ADRule.IpProtocol='tcp'
$ADRule.FromPort = 3268
$ADRule.ToPort = 3269
$ADRule.UserIdGroupPair = $DMGroup
$RpcHpRule = New-Object Amazon.EC2.Model.IpPermission
$RpcHpRule.IpProtocol='tcp'
$RpcHpRule.FromPort = 49152
$RpcHpRule.ToPort = 65535
$RpcHpRule.UserIdGroupPair = $DMGroup
Grant-EC2SecurityGroupIngress -GroupId $DomainControllersGroupId -IpPermissions $DNSRule, $KerberosRule, $RPCRule, $LDAPRule, $PasswordRule, $LDAPSRule, $ADRule, $RpcHpRule


#Domain controllers must allow numerous TCP protocols from domain members
$DNSRule = New-Object Amazon.EC2.Model.IpPermission
$DNSRule.IpProtocol='udp'
$DNSRule.FromPort = 53
$DNSRule.ToPort = 53
$DNSRule.UserIdGroupPair = $DMGroup
$KerberosRule = New-Object Amazon.EC2.Model.IpPermission
$KerberosRule.IpProtocol='udp'
$KerberosRule.FromPort = 88
$KerberosRule.ToPort = 88
$KerberosRule.UserIdGroupPair = $DMGroup
$NTPRule = New-Object Amazon.EC2.Model.IpPermission
$NTPRule.IpProtocol='udp'
$NTPRule.FromPort = 123
$NTPRule.ToPort = 123
$NTPRule.UserIdGroupPair = $DMGroup
$NetBIOSRule = New-Object Amazon.EC2.Model.IpPermission
$NetBIOSRule.IpProtocol='udp'
$NetBIOSRule.FromPort = 137
$NetBIOSRule.ToPort = 139
$NetBIOSRule.UserIdGroupPair = $DMGroup
$LDAPRule = New-Object Amazon.EC2.Model.IpPermission
$LDAPRule.IpProtocol='udp'
$LDAPRule.FromPort = 389
$LDAPRule.ToPort = 389
$LDAPRule.UserIdGroupPair = $DMGroup
$PasswordRule = New-Object Amazon.EC2.Model.IpPermission
$PasswordRule.IpProtocol='udp'
$PasswordRule.FromPort = 464
$PasswordRule.ToPort = 464
$PasswordRule.UserIdGroupPair = $DMGroup
Grant-EC2SecurityGroupIngress -GroupId $DomainControllersGroupId -IpPermissions $DNSRule, $KerberosRule, $NTPRule, $NetBIOSRule, $LDAPRule, $SMBRule, $PasswordRule
