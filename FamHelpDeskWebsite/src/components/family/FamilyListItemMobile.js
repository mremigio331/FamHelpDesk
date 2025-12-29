import React from "react";
import { List, Tag, Space, Button } from "antd";
import { TeamOutlined } from "@ant-design/icons";
import { Typography } from "antd";
import { useFamilyListItem } from "./useFamilyListItem";

const { Text } = Typography;

const FamilyListItemMobile = (props) => {
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
      style={
        onClick
          ? { cursor: "pointer", padding: "12px 0" }
          : { padding: "12px 0" }
      }
      onClick={onClick}
      actions={
        actions
          ? actions
          : defaultActions.map((action) => (
              <Button
                key={action.key}
                type="link"
                size="small"
                style={{ fontSize: "12px", padding: "0 4px" }}
                onClick={action.onClick}
              >
                {action.label}
              </Button>
            ))
      }
    >
      <List.Item.Meta
        avatar={<TeamOutlined style={{ fontSize: "18px" }} />}
        title={
          <Space size={4}>
            <span style={{ fontSize: "14px", fontWeight: "600" }}>
              {family.family_name}
            </span>
            {statusTag && (
              <Tag color={statusTag.statusColor} style={{ fontSize: "10px" }}>
                {statusTag.statusText}
              </Tag>
            )}
          </Space>
        }
        description={
          <div>
            {family.family_description && (
              <div
                style={{
                  marginBottom: "6px",
                  fontSize: "12px",
                  lineHeight: "1.4",
                }}
              >
                {family.family_description}
              </div>
            )}
            {showCreatedDate && family.created_at && (
              <Text type="secondary" style={{ fontSize: "10px" }}>
                Created: {new Date(family.created_at).toLocaleDateString()}
              </Text>
            )}
          </div>
        }
      />
    </List.Item>
  );
};

export default FamilyListItemMobile;
