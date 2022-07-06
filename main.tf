provider "aws" {
  region = var.region
}

locals {
  tags = {
    "Workspace" = terraform.workspace
    "Terraform" = "true"
  }
}

resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr
  tags = merge(local.tags, {
    "Name" = var.vpc_name
  })
}

resource "aws_subnet" "private_subnets" {
  count             = length(var.zones)
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index)
  availability_zone = "${var.region}${var.zones[count.index]}"
  tags = merge(local.tags, {
    Name = "${var.vpc_name}-private-subnet-${count.index}"
  })
}

resource "aws_subnet" "public_subnets" {
  count                   = length(var.zones)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, (100 + count.index))
  availability_zone       = "${var.region}${var.zones[count.index]}"
  map_public_ip_on_launch = true
  tags = merge(local.tags, {
    Name = "${var.vpc_name}-public-subnet-${count.index}"
  })
}

resource "aws_internet_gateway" "gw" {
  vpc_id     = aws_vpc.main.id
  depends_on = [aws_vpc.main]
  tags = merge(local.tags, {
    Name = "${var.vpc_name}-gw"
  })
}

# Public
resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.main.id
  tags = merge(local.tags, {
    Name = "${var.vpc_name}-public_route_table"
  })
}

resource "aws_route" "public_route" {
  route_table_id         = aws_route_table.public_route_table.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.gw.id
}

resource "aws_route_table_association" "public_route_table_assoc" {
  count          = length(var.zones)
  subnet_id      = element(aws_subnet.public_subnets.*.id, count.index)
  route_table_id = aws_route_table.public_route_table.id
}

resource "aws_eip" "vpc_eip" {
  count = length(var.zones)
  vpc   = true
  tags = merge(local.tags, {
    Name = "${var.vpc_name}-eip-${count.index + 1}"
  })
}

resource "aws_nat_gateway" "natgw" {
  count         = length(var.zones)
  allocation_id = aws_eip.vpc_eip[count.index].allocation_id
  subnet_id     = aws_subnet.public_subnets[count.index].id
  tags = merge(local.tags, {
    Name = "${var.vpc_name}-natgw-${count.index + 1}"
  })
}

# Private
resource "aws_route_table" "private_route_table" {
  count  = length(var.zones)
  vpc_id = aws_vpc.main.id
  tags = merge(local.tags, {
    Name = "${var.vpc_name}-private_route_table"
  })
}

resource "aws_route_table_association" "private_route_table_assoc" {
  count          = length(var.zones)
  subnet_id      = element(aws_subnet.private_subnets.*.id, count.index)
  route_table_id = element(aws_route_table.private_route_table.*.id, count.index)
}

resource "aws_route" "private_route" {
  count                  = length(var.zones)
  route_table_id         = element(aws_route_table.private_route_table.*.id, count.index)
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = element(aws_nat_gateway.natgw.*.id, count.index)
}
