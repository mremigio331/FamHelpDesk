import React, { useState, useMemo } from "react";
import { List, Empty, Input } from "antd";
import { SearchOutlined } from "@ant-design/icons";
import GroupListItem from "./GroupListItem";
import { useMobileDetection } from "../../provider/MobileDetectionProvider";

/**
 * Reusable component for displaying a list of groups
 * @param {Array} groups - Array of group objects
 * @param {Object} memberships - Map of group_id to membership objects
 * @param {Function} renderActions - Function to render custom actions for each item
 * @param {Function} onItemClick - Click handler for list items
 * @param {string} emptyDescription - Description to show when list is empty
 * @param {boolean} showCreatedDate - Whether to show created dates (default: true)
 * @param {boolean} showStats - Whether to show group stats (default: true)
 * @param {boolean} showMembershipStatus - Whether to show membership status tags (default: true)
 */
const GroupList = ({
  groups = [],
  memberships = {},
  renderActions = null,
  onItemClick = null,
  emptyDescription = "No groups found",
  showCreatedDate = true,
  showStats = true,
  showMembershipStatus = true,
}) => {
  const [searchQuery, setSearchQuery] = useState("");
  const { isMobile } = useMobileDetection();

  // Filter and sort groups
  const filteredAndSortedGroups = useMemo(() => {
    let result = [...groups];

    // Filter by search query
    if (searchQuery.trim()) {
      const query = searchQuery.toLowerCase();
      result = result.filter(
        (group) =>
          group.group_name.toLowerCase().includes(query) ||
          (group.group_description &&
            group.group_description.toLowerCase().includes(query)),
      );
    }

    // Sort alphabetically by group name
    result.sort((a, b) =>
      a.group_name.localeCompare(b.group_name, undefined, {
        sensitivity: "base",
      }),
    );

    return result;
  }, [groups, searchQuery]);

  if (groups.length === 0) {
    return (
      <Empty
        description={emptyDescription}
        image={Empty.PRESENTED_IMAGE_SIMPLE}
      />
    );
  }

  return (
    <div>
      {/* Search Bar */}
      <Input
        placeholder="Search groups by name or description..."
        prefix={<SearchOutlined />}
        value={searchQuery}
        onChange={(e) => setSearchQuery(e.target.value)}
        style={{
          marginBottom: isMobile ? "12px" : "16px",
          fontSize: isMobile ? "16px" : "14px",
          height: isMobile ? "44px" : "32px",
        }}
        allowClear
      />

      {/* Groups List */}
      {filteredAndSortedGroups.length === 0 ? (
        <Empty
          description="No groups match your search"
          image={Empty.PRESENTED_IMAGE_SIMPLE}
        />
      ) : (
        <List
          itemLayout="horizontal"
          dataSource={filteredAndSortedGroups}
          style={{
            backgroundColor: isMobile ? "#f5f5f5" : "transparent",
            padding: isMobile ? "4px" : "0",
            borderRadius: isMobile ? "8px" : "0",
          }}
          renderItem={(group) => {
            const membership = memberships[group.group_id] || null;
            const actions = renderActions
              ? renderActions(group, membership)
              : null;
            const handleClick = onItemClick
              ? () => onItemClick(group, membership)
              : null;

            return (
              <GroupListItem
                group={group}
                membership={membership}
                actions={actions}
                onClick={handleClick}
                showCreatedDate={showCreatedDate}
                showStats={showStats}
                showMembershipStatus={showMembershipStatus}
              />
            );
          }}
        />
      )}
    </div>
  );
};

export default GroupList;
