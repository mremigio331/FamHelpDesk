import {
  Stack,
  StackProps,
  Duration,
  aws_s3 as s3,
  aws_cloudfront as cloudfront,
  aws_cloudfront_origins as origins,
  aws_route53 as route53,
  aws_certificatemanager as acm,
  aws_route53_targets as targets,
  aws_iam as iam,
  aws_s3_deployment as s3deploy,
  RemovalPolicy,
} from "aws-cdk-lib";
import { Construct } from "constructs";
import * as path from "path";
import { famHelpDesk } from "../constants";

interface WebsiteStackProps extends StackProps {
  websiteDomainName: string;
  rootDomainName: string;
  certificateArn: string;
  hostedZoneId: string;
  stage: string;
}

export class WebsiteStack extends Stack {
  public readonly distribution: cloudfront.Distribution;
  public readonly bucket: s3.Bucket;

  constructor(scope: Construct, id: string, props: WebsiteStackProps) {
    super(scope, id, props);

    const {
      websiteDomainName,
      rootDomainName,
      certificateArn,
      hostedZoneId,
      stage,
    } = props;

    // Create S3 bucket for static website hosting
    this.bucket = new s3.Bucket(this, `${famHelpDesk}-WebsiteBucket-${stage}`, {
      bucketName: `${famHelpDesk.toLowerCase()}-website-${stage.toLowerCase()}`,
      publicReadAccess: false,
      blockPublicAccess: s3.BlockPublicAccess.BLOCK_ALL,
      removalPolicy: RemovalPolicy.DESTROY,
      autoDeleteObjects: true,
      versioned: true,
    });

    // Create Origin Access Control for CloudFront
    const originAccessControl = new cloudfront.S3OriginAccessControl(
      this,
      `${famHelpDesk}-WebsiteOAC-${stage}`,
      {
        description: `Origin Access Control for ${famHelpDesk} Website ${stage}`,
      },
    );

    // Build S3 origin with OAC
    const s3Origin = origins.S3BucketOrigin.withOriginAccessControl(this.bucket, {
      originAccessControl,
    });

    // Import the certificate (must be in us-east-1 for CloudFront)
    const certificate = acm.Certificate.fromCertificateArn(
      this,
      `${famHelpDesk}-WebsiteCert-${stage}`,
      certificateArn,
    );

    // Create CloudFront distribution
    this.distribution = new cloudfront.Distribution(
      this,
      `${famHelpDesk}-WebsiteDistribution-${stage}`,
      {
        comment: `${famHelpDesk} Website Distribution ${stage}`,
        defaultBehavior: {
          origin: s3Origin,
          viewerProtocolPolicy: cloudfront.ViewerProtocolPolicy.REDIRECT_TO_HTTPS,
          allowedMethods: cloudfront.AllowedMethods.ALLOW_GET_HEAD,
          cachedMethods: cloudfront.CachedMethods.CACHE_GET_HEAD,
          cachePolicy: cloudfront.CachePolicy.CACHING_OPTIMIZED,
          compress: true,
        },
        domainNames: [websiteDomainName],
        certificate: certificate,
        minimumProtocolVersion: cloudfront.SecurityPolicyProtocol.TLS_V1_2_2021,
        httpVersion: cloudfront.HttpVersion.HTTP2_AND_3,
        priceClass: cloudfront.PriceClass.PRICE_CLASS_100,
        defaultRootObject: "index.html",
        errorResponses: [
          {
            httpStatus: 404,
            responseHttpStatus: 404,
            responsePagePath: "/404.html",
            ttl: Duration.minutes(5),
          },
          {
            httpStatus: 403,
            responseHttpStatus: 404,
            responsePagePath: "/404.html",
            ttl: Duration.minutes(5),
          },
        ],
        enableIpv6: true,
      },
    );

    // Allow CloudFront to read bucket via OAC (scoped to this distribution)
    this.bucket.addToResourcePolicy(
      new iam.PolicyStatement({
        effect: iam.Effect.ALLOW,
        principals: [new iam.ServicePrincipal("cloudfront.amazonaws.com")],
        actions: ["s3:GetObject"],
        resources: [`${this.bucket.bucketArn}/*`],
        conditions: {
          StringEquals: {
            "AWS:SourceArn": `arn:aws:cloudfront::${this.account}:distribution/${this.distribution.distributionId}`,
          },
        },
      }),
    );

    // DNS Configuration
    const hostedZone = route53.HostedZone.fromHostedZoneAttributes(
      this,
      `${famHelpDesk}-WebsiteHostedZone-${stage}`,
      {
        hostedZoneId,
        zoneName: rootDomainName,
      },
    );

    // Create A record pointing to CloudFront distribution
    new route53.ARecord(this, `${famHelpDesk}-WebsiteARecord-${stage}`, {
      recordName: websiteDomainName === rootDomainName ? undefined : websiteDomainName.replace(`.${rootDomainName}`, ""),
      zone: hostedZone,
      target: route53.RecordTarget.fromAlias(
        new targets.CloudFrontTarget(this.distribution),
      ),
    });

    // Website content deployment
    const siteOutputPath = path.join(__dirname, "../../../FamHelpDeskWebsite/dist");

    // Deploy website files to S3 bucket
    new s3deploy.BucketDeployment(this, `${famHelpDesk}-WebsiteDeployment-${stage}`, {
      destinationBucket: this.bucket,
      sources: [s3deploy.Source.asset(siteOutputPath)],
      distribution: this.distribution,
      distributionPaths: ["/", "/index.html", "/*"], // Invalidate cache for all files
      cacheControl: [
        s3deploy.CacheControl.fromString("public, max-age=0, must-revalidate")
      ],
    });
  }
}