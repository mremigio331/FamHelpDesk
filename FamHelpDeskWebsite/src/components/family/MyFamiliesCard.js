import React from "react";
import { Card, List, Tag, Space, Empty, Alert, Button } from "antd";
import { TeamOutlined } from "@ant-design/icons";
import { Typography } from "antd";
import { useNavigate } from "react-router-dom";
import { useMyFamilies } from "../../provider/MyFamiliesProvider";

const { Text } = Typography;

const MyFamiliesCard = () => {
  const navigate = useNavigate();
  const { familiesArray, isMyFamiliesError, myFamiliesError } = useMyFamilies();

  return (
    <Card
      title={
        <Space>
          <TeamOutlined />
          <span>My Families</span>
        </Space>
      }
    >
      {isMyFamiliesError ? (
        <Alert
          message="Error loading families"
          description={
            myFamiliesError?.message || "Failed to load your families"
          }
          type="error"
          showIcon
        />
      ) : familiesArray.length === 0 ? (
        <Empty
          description="You are not part of any families yet"
          image={Empty.PRESENTED_IMAGE_SIMPLE}
        />
      ) : (
        <List
          itemLayout="horizontal"
          dataSource={familiesArray}
          renderItem={(item) => {
            const family = item.family;
            const membership = item.membership;
            const statusColor =
              membership.status === "MEMBER" ? "green" : "orange";
            const statusText =
              membership.status === "MEMBER" ? "Member" : "Pending";

            return (
              <List.Item
                style={{ cursor: "pointer" }}
                onClick={() => navigate(`/family/${family.family_id}`)}
                actions={[
                  <Button
                    type="link"
                    onClick={(e) => {
                      e.stopPropagation();
                      navigate(`/family/${family.family_id}`);
                    }}
                  >
                    View
                  </Button>,
                ]}
              >
                <List.Item.Meta
                  avatar={<TeamOutlined style={{ fontSize: "24px" }} />}
                  title={
                    <Space>
                      <span>{family.family_name}</span>
                      <Tag color={statusColor}>{statusText}</Tag>
                    </Space>
                  }
                  description={
                    <div>
                      {family.family_description && (
                        <div style={{ marginBottom: "8px" }}>
                          {family.family_description}
                        </div>
                      )}
                      <Text type="secondary" style={{ fontSize: "12px" }}>
                        Created:{" "}
                        {new Date(family.created_at).toLocaleDateString()}
                      </Text>
                    </div>
                  }
                />
              </List.Item>
            );
          }}
        />
      )}
    </Card>
  );
};

export default MyFamiliesCard;
