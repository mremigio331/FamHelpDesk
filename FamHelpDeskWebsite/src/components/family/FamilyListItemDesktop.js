import React from "react";
import { List, Tag, Space, Button } from "antd";
import { TeamOutlined } from "@ant-design/icons";
import { Typography } from "antd";
import { useFamilyListItem } from "./useFamilyListItem";

const { Text } = Typography;

const FamilyListItemDesktop = (props) => {
  const {
    family,
    membership = null,
    actions = null,
    onClick = null,
    showCreatedDate = true,
  } = props;
  const { statusTag, defaultActions } = useFamilyListItem({
    family,
    membership,
    actions,
  });

  return (
    <List.Item
      style={onClick ? { cursor: "pointer" } : {}}
      onClick={onClick}
      actions={defaultActions.map((action) => (
        <Button key={action.key} type="link" onClick={action.onClick}>
          {action.label}
        </Button>
      ))}
    >
      <List.Item.Meta
        avatar={<TeamOutlined style={{ fontSize: "24px" }} />}
        title={
          <Space>
            <span>{family.family_name}</span>
            {statusTag && (
              <Tag color={statusTag.statusColor}>{statusTag.statusText}</Tag>
            )}
          </Space>
        }
        description={
          <div>
            {family.family_description && (
              <div style={{ marginBottom: "8px" }}>
                {family.family_description}
              </div>
            )}
            {showCreatedDate && family.created_at && (
              <Text type="secondary" style={{ fontSize: "12px" }}>
                Created: {new Date(family.created_at).toLocaleDateString()}
              </Text>
            )}
          </div>
        }
      />
    </List.Item>
  );
};

export default FamilyListItemDesktop;
