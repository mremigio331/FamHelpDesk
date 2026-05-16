import {
  Stack,
  StackProps,
  Duration,
  RemovalPolicy,
  aws_s3 as s3,
} from "aws-cdk-lib";
import { Construct } from "constructs";

interface FamGrabStackProps extends StackProps {
  stage: string;
}

export class FamGrabStack extends Stack {
  public readonly photosBucket: s3.Bucket;

  constructor(scope: Construct, id: string, props: FamGrabStackProps) {
    super(scope, id, props);

    const { stage } = props;

    this.photosBucket = new s3.Bucket(this, `FamGrab-PhotosBucket-${stage}`, {
      bucketName: `famhelpdesk-famgrab-photos-${stage.toLowerCase()}`,
      blockPublicAccess: s3.BlockPublicAccess.BLOCK_ALL,
      removalPolicy: RemovalPolicy.DESTROY,
      lifecycleRules: [
        {
          expiration: Duration.days(90),
        },
      ],
      cors: [
        {
          allowedMethods: [s3.HttpMethods.PUT],
          allowedOrigins: [
            "https://famhelpdesk.com",
            "https://testing.famhelpdesk.com",
            "http://localhost:8080",
          ],
          allowedHeaders: ["*"],
          exposedHeaders: ["ETag"],
          maxAge: 3600,
        },
      ],
    });
  }
}
