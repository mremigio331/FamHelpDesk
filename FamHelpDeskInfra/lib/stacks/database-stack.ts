import { Stack, StackProps, RemovalPolicy } from "aws-cdk-lib";
import { Construct } from "constructs";
import * as dynamodb from "aws-cdk-lib/aws-dynamodb";
import { famHelpDesk } from "../constants";

interface DatabaseStackProps extends StackProps {
  stage: string;
}

export class DatabaseStack extends Stack {
  public readonly table: dynamodb.Table;

  constructor(scope: Construct, id: string, props: DatabaseStackProps) {
    super(scope, id, props);

    const { stage } = props;

    this.table = new dynamodb.Table(this, `${famHelpDesk}-${stage}`, {
      tableName: `${famHelpDesk}-${stage}`,
      partitionKey: {
        name: "pk",
        type: dynamodb.AttributeType.STRING,
      },
      sortKey: {
        name: "sk",
        type: dynamodb.AttributeType.STRING,
      },
      billingMode: dynamodb.BillingMode.PAY_PER_REQUEST,
      removalPolicy: RemovalPolicy.DESTROY,
    });

    // GSI for querying tickets by family ordered by last_update_time
    this.table.addGlobalSecondaryIndex({
      indexName: "TicketTimeIndex",
      partitionKey: {
        name: "family_id",
        type: dynamodb.AttributeType.STRING,
      },
      sortKey: {
        name: "last_update_time",
        type: dynamodb.AttributeType.NUMBER,
      },
      projectionType: dynamodb.ProjectionType.ALL,
    });

    // GSI for direct ticket lookup by ticket_id only
    this.table.addGlobalSecondaryIndex({
      indexName: "TicketIdIndex",
      partitionKey: {
        name: "ticket_id",
        type: dynamodb.AttributeType.STRING,
      },
      projectionType: dynamodb.ProjectionType.ALL,
    });

    // GSI for entity name lookup by UUID
    this.table.addGlobalSecondaryIndex({
      indexName: "entity-name-lookup-index",  // Different name
      partitionKey: {
        name: "entity_uuid",
        type: dynamodb.AttributeType.STRING,
      },
      sortKey: {
        name: "entity_name",
        type: dynamodb.AttributeType.STRING,
      },
      projectionType: dynamodb.ProjectionType.ALL,
    });
  }
}
