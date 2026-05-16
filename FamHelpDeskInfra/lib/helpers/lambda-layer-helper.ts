import { Construct } from "constructs";
import * as lambda from "aws-cdk-lib/aws-lambda";
import * as path from "path";
import { famHelpDesk } from "../constants";

// Cache to store the created Lambda Layer to ensure reuse
const layerCache: { [key: string]: lambda.LayerVersion } = {};
/**
 * Helper function to create or reuse a Python-specific Lambda Layer.
 * @param scope - The CDK stack scope.
 * @returns The shared Python Lambda Layer.
 */
export function createPythonLambdaLayer(
  scope: Construct,
  stage: string,
): lambda.LayerVersion {
  const layerName = `${famHelpDesk}-PythonSharedLayer-${stage}`;

  if (!layerCache[layerName]) {
    layerCache[layerName] = new lambda.LayerVersion(scope, layerName, {
      code: lambda.Code.fromAsset(
        path.join(__dirname, "../../../FamHelpDeskBackend/lambda_layer.zip"),
      ),
      compatibleRuntimes: [lambda.Runtime.PYTHON_3_11],
      description: `${famHelpDesk} Lambda layer with dependencies`,
    });
  }

  return layerCache[layerName];
}
