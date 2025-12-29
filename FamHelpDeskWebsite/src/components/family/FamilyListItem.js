import React from "react";
import { List, Tag, Space, Button } from "antd";
import { TeamOutlined } from "@ant-design/icons";
import { Typography } from "antd";
import { useNavigate } from "react-router-dom";

const { Text } = Typography;

/**
 * Reusable component for displaying a family in a list
 * @param {Object} family - The family object
 * @param {Object} membership - The membership object (optional)
 * @param {Array} actions - Custom action buttons to display
 * @param {Function} onClick - Click handler for the list item
 * @param {boolean} showCreatedDate - Whether to show the created date (default: true)
 */
const FamilyListItem = ({
  family,
  membership = null,
  actions = null,
  onClick = null,
  showCreatedDate = true,
}) => {
  const navigate = useNavigate();

  // Determine status based on membership
  let statusTag = null;
  if (membership) {
    let statusColor = "green";
    let statusText = "Member";

    if (membership.status === "AWAITING") {
      statusColor = "orange";
      statusText = "Pending";
    } else if (membership.status === "DECLINED") {
      statusColor = "red";
      statusText = "Declined";
    }

    statusTag = <Tag color={statusColor}>{statusText}</Tag>;
  }

  // Default actions if none provided
  const defaultActions = actions || [
    <Button
      type="link"
      onClick={(e) => {
        e.stopPropagation();
        navigate(`/family/${family.family_id}`);
      }}
    >
      View
    </Button>,
  ];

  return (
    <List.Item
      style={onClick ? { cursor: "pointer" } : {}}
      onClick={onClick}
      actions={defaultActions}
    >
      <List.Item.Meta
        avatar={<TeamOutlined style={{ fontSize: "24px" }} />}
        title={
          <Space>
            <span>{family.family_name}</span>
            {statusTag}
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

export default FamilyListItem;
