import React from "react";
import { List, Empty } from "antd";
import FamilyListItem from "./FamilyListItem";

/**
 * Reusable component for displaying a list of families
 * @param {Array} families - Array of family objects
 * @param {Object} memberships - Map of family_id to membership objects
 * @param {Function} renderActions - Function to render custom actions for each item
 * @param {Function} onItemClick - Click handler for list items
 * @param {string} emptyDescription - Description to show when list is empty
 * @param {boolean} showCreatedDate - Whether to show created dates (default: true)
 */
const FamilyList = ({
  families = [],
  memberships = {},
  renderActions = null,
  onItemClick = null,
  emptyDescription = "No families found",
  showCreatedDate = true,
}) => {
  if (families.length === 0) {
    return (
      <Empty
        description={emptyDescription}
        image={Empty.PRESENTED_IMAGE_SIMPLE}
      />
    );
  }

  return (
    <List
      itemLayout="horizontal"
      dataSource={families}
      renderItem={(family) => {
        const membership = memberships[family.family_id] || null;
        const actions = renderActions
          ? renderActions(family, membership)
          : null;
        const handleClick = onItemClick
          ? () => onItemClick(family, membership)
          : null;

        return (
          <FamilyListItem
            family={family}
            membership={membership}
            actions={actions}
            onClick={handleClick}
            showCreatedDate={showCreatedDate}
          />
        );
      }}
    />
  );
};

export default FamilyList;
