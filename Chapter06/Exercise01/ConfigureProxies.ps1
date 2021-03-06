
#This script will add a new public subnet with a NAT and RDP Gateway as discussed in exercise 1 of chapter 5  
#This script assumes that you already have a VPC in place similar to that discussed throughout most of chapter 5 

param
(
    [string][parameter(mandatory=$true)]$VPCID,
    [string][parameter(mandatory=$false)]$ResourcesSubnetCIDR = '192.168.0.0/24',
    [string][parameter(mandatory=$false)]$NAT_AMI,
    [string][parameter(mandatory=$false)]$RDP_AMI
)

If([System.String]::IsNullOrEmpty($NAT_AMI)){ $NAT_AMI = (Get-EC2ImageByName -Name 'VPC_NAT')[0].ImageId}
If([System.String]::IsNullOrEmpty($RDP_AMI)){ $RDP_AMI = (Get-EC2ImageByName -Name 'WINDOWS_2008_BASE')[0].ImageId}

#Get a reference to the VPC and first availability zone in the region.
$VPC = Get-EC2VPC -VpcID $VPCID
$AvailabilityZones = Get-EC2AvailabilityZone
$AvailabilityZone = $AvailabilityZones[0].ZoneName

#Create a new subnet for our management instances (NAT and RDP Gateway) and configure its route table
$ResourcesSubnet = New-EC2Subnet -VpcId $VPC.VpcId -CidrBlock $ResourcesSubnetCIDR -AvailabilityZone $AvailabilityZone
$ResourcesRouteTable = New-EC2RouteTable -VpcId $VPC.VpcId
$VPCFilter = New-Object Amazon.EC2.Model.Filter
$VPCFilter.Name = 'attachment.vpc-id'
$VPCFilter.Value = $VPC.VpcId
$InternetGateway = Get-EC2InternetGateway -Filter $VPCFilter
New-EC2Route -RouteTableId $ResourcesRouteTable.RouteTableId -DestinationCidrBlock '0.0.0.0/0' -GatewayId $InternetGateway.InternetGatewayId
Register-EC2RouteTable -RouteTableId $ResourcesRouteTable.RouteTableId -SubnetId $ResourcesSubnet.SubnetId

#Create ACLs to allow administration of the new instances
$ACL = New-EC2NetworkAcl -VpcId $VPCID
New-EC2NetworkAclEntry -NetworkAclId $ACL.NetworkAclId -RuleNumber 100 -CidrBlock '0.0.0.0/0' -Egress $false -PortRange_From 22 -PortRange_To 22 -Protocol 6 -RuleAction Allow 
New-EC2NetworkAclEntry -NetworkAclId $ACL.NetworkAclId -RuleNumber 110 -CidrBlock '0.0.0.0/0' -Egress $false -PortRange_From 3389 -PortRange_To 3389 -Protocol 6 -RuleAction Allow 
New-EC2NetworkAclEntry -NetworkAclId $ACL.NetworkAclId -RuleNumber 120 -CidrBlock '0.0.0.0/0' -Egress $true  -PortRange_From 49152 -PortRange_To 65535 -Protocol 6 -RuleAction Allow 

#Create ACLs to allow HTTP and HTTPS trough the NAT Gateway
New-EC2NetworkAclEntry -NetworkAclId $ACL.NetworkAclId -RuleNumber 200 -CidrBlock $VPC.CidrBlock -Egress $false -PortRange_From 80 -PortRange_To 80 -Protocol 6 -RuleAction Allow 
New-EC2NetworkAclEntry -NetworkAclId $ACL.NetworkAclId -RuleNumber 210 -CidrBlock $VPC.CidrBlock -Egress $false -PortRange_From 443 -PortRange_To 443 -Protocol 6 -RuleAction Allow 
New-EC2NetworkAclEntry -NetworkAclId $ACL.NetworkAclId -RuleNumber 230 -CidrBlock $VPC.CidrBlock -Egress $true -PortRange_From 49152 -PortRange_To 65535 -Protocol 6 -RuleAction Allow 
New-EC2NetworkAclEntry -NetworkAclId $ACL.NetworkAclId -RuleNumber 240 -CidrBlock '0.0.0.0/0' -Egress $true -PortRange_From 80 -PortRange_To 80 -Protocol 6 -RuleAction Allow 
New-EC2NetworkAclEntry -NetworkAclId $ACL.NetworkAclId -RuleNumber 250 -CidrBlock '0.0.0.0/0' -Egress $true -PortRange_From 443 -PortRange_To 443 -Protocol 6 -RuleAction Allow 
New-EC2NetworkAclEntry -NetworkAclId $ACL.NetworkAclId -RuleNumber 260 -CidrBlock '0.0.0.0/0' -Egress $false -PortRange_From 49152 -PortRange_To 65535 -Protocol 6 -RuleAction Allow 

#Create ACLs to allow RDP through the Remote Desktop Gateway
New-EC2NetworkAclEntry -NetworkAclId $ACL.NetworkAclId -RuleNumber 300 -CidrBlock '0.0.0.0/0' -Egress $false -PortRange_From 443 -PortRange_To 443 -Protocol 6 -RuleAction Allow 
New-EC2NetworkAclEntry -NetworkAclId $ACL.NetworkAclId -RuleNumber 310 -CidrBlock '0.0.0.0/0' -Egress $true -PortRange_From 49152 -PortRange_To 65535 -Protocol 6 -RuleAction Allow 
New-EC2NetworkAclEntry -NetworkAclId $ACL.NetworkAclId -RuleNumber 320 -CidrBlock $VPC.CidrBlock -Egress $true -PortRange_From 3389 -PortRange_To 3389 -Protocol 6 -RuleAction Allow 
New-EC2NetworkAclEntry -NetworkAclId $ACL.NetworkAclId -RuleNumber 330 -CidrBlock $VPC.CidrBlock -Egress $false -PortRange_From 49152 -PortRange_To 65535 -Protocol 6 -RuleAction Allow 

#Create an admin group for initial instance configuration
$RDPRule = New-Object Amazon.EC2.Model.IpPermission
$RDPRule.IpProtocol='tcp'
$RDPRule.FromPort = 3389
$RDPRule.ToPort = 3389
$RDPRule.IpRanges = '0.0.0.0/0'
$SSHRule = New-Object Amazon.EC2.Model.IpPermission
$SSHRule.IpProtocol='tcp'
$SSHRule.FromPort = 22
$SSHRule.ToPort = 22
$SSHRule.IpRanges = '0.0.0.0/0'
$AdminGroupId = New-EC2SecurityGroup -VpcId $VPCID -GroupName 'Admin' -GroupDescription "Allows RDP and SSH for configuration." 
Grant-EC2SecurityGroupIngress -GroupId $AdminGroupId -IpPermissions $RDPRule, $SSHRule

#Create Security Group to allow HTTP and HTTPS trough the NAT Gateway
$HTTPRule = New-Object Amazon.EC2.Model.IpPermission
$HTTPRule.IpProtocol='tcp'
$HTTPRule.FromPort = 80
$HTTPRule.ToPort = 80
$HTTPRule.IpRanges = $VPC.CidrBlock
$HTTPSRule = New-Object Amazon.EC2.Model.IpPermission
$HTTPSRule.IpProtocol='tcp'
$HTTPSRule.FromPort = 443
$HTTPSRule.ToPort = 443
$HTTPSRule.IpRanges = $VPC.CidrBlock
$NatGroupId = New-EC2SecurityGroup -VpcId $VPCID -GroupName 'NATGateway' -GroupDescription "Allows HTTP/S from the VPC to the internet." 
Grant-EC2SecurityGroupIngress -GroupId $NatGroupId -IpPermissions $HTTPRule, $HTTPSRule

#Create Security Group to allow RDP through the Remote Desktop Gateway
$RDPRule = New-Object Amazon.EC2.Model.IpPermission
$RDPRule.IpProtocol='tcp'
$RDPRule.FromPort = 443
$RDPRule.ToPort = 443
$RDPRule.IpRanges = '0.0.0.0/0'
$RdpGroupId = New-EC2SecurityGroup -VpcId $VPCID -GroupName 'RDPGateway' -GroupDescription "Allows RDP over HTTPS from the internet." 
Grant-EC2SecurityGroupIngress -GroupId $RdpGroupId -IpPermissions $RDPRule

#Add a rule to the default group to allow RDP from the RDP gateway
$VPCFilter = New-Object Amazon.EC2.Model.Filter
$VPCFilter.Name = 'vpc-id'
$VPCFilter.Value = $VPCID
$GroupFilter = New-Object Amazon.EC2.Model.Filter
$GroupFilter.Name = 'group-name'
$GroupFilter.Value = 'default'
$DefaultGroup = Get-EC2SecurityGroup -Filter $VPCFilter, $GroupFilter
$RDPGatewayGroup = New-Object Amazon.EC2.Model.UserIdGroupPair 
$RDPGatewayGroup.GroupId = $RdpGroupId
$RDPRule = New-Object Amazon.EC2.Model.IpPermission
$RDPRule.IpProtocol='tcp'
$RDPRule.FromPort = 3389
$RDPRule.ToPort = 3389
$RDPRule.UserIdGroupPair = $RDPGatewayGroup
Grant-EC2SecurityGroupIngress -GroupId $DefaultGroup.GroupId -IpPermissions $RDPRule

#Associate the Resources Subnet with the new ACLs
$VPCFilter = New-Object Amazon.EC2.Model.Filter
$VPCFilter.Name = 'vpc-id'
$VPCFilter.Value = $VPCID
$DefaultFilter = New-Object Amazon.EC2.Model.Filter
$DefaultFilter.Name = 'default'
$DefaultFilter.Value = 'true'
$OldACL = (Get-EC2NetworkAcl -Filter $VPCFilter, $DefaultFilter )
$OldAssociation = $OldACL.Associations | Where-Object { $_.SubnetId -eq $ResourcesSubnet.SubnetId }
$NoEcho = Set-EC2NetworkAclAssociation -AssociationId $OldAssociation.NetworkAclAssociationId -NetworkAclId $ACL.NetworkAclId

#Launch a new instance for the NAT Gateway.  
$Reservation = New-EC2Instance -ImageId $NAT_AMI -KeyName 'MyKey' -InstanceType 't1.micro' -MinCount 1 -MaxCount 1 -SubnetId $ResourcesSubnet.SubnetId -SecurityGroupId $NatGroupId, $AdminGroupId
$NATInstance = $Reservation.RunningInstance[0]
$Tag = New-Object Amazon.EC2.Model.Tag
$Tag.Key = 'Name'
$Tag.Value = 'NATGateway'
New-EC2Tag -ResourceId $NATInstance.InstanceID  -Tag $tag

#Wait for the NAT instance to boot
Start-Sleep -s 60
While ((Get-EC2InstanceStatus -InstanceId $NATInstance.InstanceID).InstanceState.name -ne 'running')
{
    Start-Sleep -s 60 
    $NATInstance = (Get-EC2Instance -Instance $NATInstance.InstanceID).RunningInstance[0]
}


#Disable the source/destination check
$NIC = $NATInstance.NetworkInterfaces[0]
Edit-EC2NetworkInterfaceAttribute -NetworkInterfaceId $NIC.NetworkInterfaceId  -SourceDestCheck $false
#NOTE: The previous line is failing.  Appears to be an issue with the PowerShell API.  Contacting Amazon.

#Assign a Elastic IP
$EIP = New-EC2Address -Domain 'vpc'
Start-Sleep -s 15 #This can take a few seconds
Register-EC2Address -InstanceId $NATInstance.InstanceID -AllocationId $EIP.AllocationId

#Find the Main Route Table for this VPC
$VPCFilter = New-Object Amazon.EC2.Model.Filter
$VPCFilter.Name = 'vpc-id'
$VPCFilter.Value = $VPC.VpcId
$IsDefaultFilter = New-Object Amazon.EC2.Model.Filter
$IsDefaultFilter.Name = 'association.main'
$IsDefaultFilter.Value = 'true'
$MainRouteTable = (Get-EC2RouteTable -Filter $VPCFilter, $IsDefaultFilter)

#Replace the default route with reference to the NAT gateway
$MainRouteTable.Routes | Where-Object { $_.DestinationCidrBlock -eq '0.0.0.0/0'} | % {Remove-EC2Route -RouteTableId $MainRouteTable.RouteTableId -DestinationCidrBlock $_.DestinationCidrBlock -Force}
New-EC2Route -RouteTableId $MainRouteTable.RouteTableId  -DestinationCidrBlock '0.0.0.0/0' -InstanceId $NATInstance.InstanceId


#Create a user data script to configure the RDP Gateway
$UserData = @'
<powershell>
Add-WindowsFeature -Name RDS-Gateway -IncludeAllSubFeature
</powershell>
'@
$UserData = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($UserData))

#Launch a new instance for the RDP Gateway passing in the configuration script as user data.  
$Reservation = New-EC2Instance -ImageId $RDP_AMI -KeyName 'MyKey' -InstanceType 't1.micro' -MinCount 1 -MaxCount 1 -SubnetId $ResourcesSubnet.SubnetId -SecurityGroupId $RdpGroupId, $AdminGroupId -UserData $UserData
$RDPInstance = $Reservation.RunningInstance[0]
$Tag = New-Object Amazon.EC2.Model.Tag
$Tag.Key = 'Name'
$Tag.Value = 'RDPGateway'
New-EC2Tag -ResourceId $RDPInstance.InstanceID  -Tag $tag

#Wait for the RDP instance to boot
Start-Sleep -s 60
While ((Get-EC2InstanceStatus -InstanceId $RDPInstance.InstanceID).InstanceState.name -ne 'running')
{
    Start-Sleep -s 60 
    $RDPInstance = (Get-EC2Instance -Instance $RDPInstance.InstanceID).RunningInstance[0]
}

#Assign a Elastic IP
$EIP = New-EC2Address -Domain 'vpc'
Start-Sleep -s 15 #This can take a few seconds
Register-EC2Address -InstanceId $RDPInstance.InstanceID -AllocationId $EIP.AllocationId


