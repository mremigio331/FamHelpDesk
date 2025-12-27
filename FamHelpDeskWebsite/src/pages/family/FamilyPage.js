import React from "react";
import { useParams, useNavigate } from "react-router-dom";
import {
  Card,
  Typography,
  Button,
  Space,
  Spin,
  Alert,
  Descriptions,
} from "antd";
import { ArrowLeftOutlined, TeamOutlined } from "@ant-design/icons";
import { useMyFamilies } from "../../provider/MyFamiliesProvider";

const { Title, Text } = Typography;

const FamilyPage = () => {
  const { familyId } = useParams();
  const navigate = useNavigate();
  const { myFamilies, isMyFamiliesFetching, isMyFamiliesError } =
    useMyFamilies();

  if (isMyFamiliesFetching) {
    return (
      <div style={{ padding: "50px", textAlign: "center" }}>
        <Spin size="large" />
      </div>
    );
  }

  if (isMyFamiliesError) {
    return (
      <div style={{ padding: "50px", maxWidth: "600px", margin: "0 auto" }}>
        <Alert
          message="Error"
          description="Failed to load family information"
          type="error"
          showIcon
        />
      </div>
    );
  }

  const familyData = myFamilies[familyId];

  if (!familyData) {
    return (
      <div style={{ padding: "50px", maxWidth: "600px", margin: "0 auto" }}>
        <Alert
          message="Family Not Found"
          description="You do not have access to this family or it does not exist."
          type="warning"
          showIcon
          action={
            <Button type="primary" onClick={() => navigate("/")}>
              Go Home
            </Button>
          }
        />
      </div>
    );
  }

  const { family, membership } = familyData;

  return (
    <div style={{ padding: "50px", maxWidth: "1200px", margin: "0 auto" }}>
      <Space direction="vertical" size="large" style={{ width: "100%" }}>
        <div>
          <Button
            type="link"
            icon={<ArrowLeftOutlined />}
            onClick={() => navigate("/")}
            style={{ paddingLeft: 0 }}
          >
            Back to Home
          </Button>
        </div>

        <Card>
          <Space direction="vertical" size="middle" style={{ width: "100%" }}>
            <div
              style={{
                display: "flex",
                alignItems: "center",
                gap: "12px",
              }}
            >
              <TeamOutlined style={{ fontSize: "32px" }} />
              <Title level={2} style={{ margin: 0 }}>
                {family.family_name}
              </Title>
            </div>

            {family.family_description && (
              <Text type="secondary" style={{ fontSize: "16px" }}>
                {family.family_description}
              </Text>
            )}

            <Descriptions bordered column={1}>
              <Descriptions.Item label="Your Status">
                {membership.status === "MEMBER" ? "Member" : "Pending"}
              </Descriptions.Item>
              <Descriptions.Item label="Created">
                {new Date(family.created_at).toLocaleDateString()}
              </Descriptions.Item>
              <Descriptions.Item label="Family ID">
                <Text code copyable style={{ fontSize: "12px" }}>
                  {family.family_id}
                </Text>
              </Descriptions.Item>
            </Descriptions>
          </Space>
        </Card>

        <Card title="Groups">
          <Alert
            message="Coming Soon"
            description="Groups for this family will be displayed here."
            type="info"
            showIcon
          />
        </Card>

        <Card title="Members">
          <Alert
            message="Coming Soon"
            description="Family members will be displayed here."
            type="info"
            showIcon
          />
        </Card>

        <Card title="Tickets">
          <Alert
            message="Coming Soon"
            description="Support tickets for this family will be displayed here."
            type="info"
            showIcon
          />
        </Card>
      </Space>
    </div>
  );
};

export default FamilyPage;
