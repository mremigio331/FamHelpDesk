import React, { useState, useMemo } from "react";
import { List, Empty, Input } from "antd";
import { SearchOutlined } from "@ant-design/icons";
import QueueListItem from "./QueueListItem";

/**
 * Reusable component for displaying a list of queues
 * @param {Array} queues - Array of queue objects
 * @param {Function} renderActions - Function to render custom actions for each item
 * @param {Function} onItemClick - Click handler for list items
 * @param {string} emptyDescription - Description to show when list is empty
 * @param {boolean} showCreatedDate - Whether to show created dates (default: true)
 * @param {boolean} showStats - Whether to show queue stats (default: true)
 */
const QueueList = ({
  queues = [],
  renderActions = null,
  onItemClick = null,
  emptyDescription = "No queues found",
  showCreatedDate = true,
  showStats = true,
}) => {
  const [searchQuery, setSearchQuery] = useState("");

  // Filter and sort queues
  const filteredAndSortedQueues = useMemo(() => {
    let result = [...queues];

    // Filter by search query
    if (searchQuery.trim()) {
      const query = searchQuery.toLowerCase();
      result = result.filter(
        (queue) =>
          queue.queue_name.toLowerCase().includes(query) ||
          (queue.queue_description &&
            queue.queue_description.toLowerCase().includes(query)),
      );
    }

    // Sort alphabetically by queue name
    result.sort((a, b) =>
      a.queue_name.localeCompare(b.queue_name, undefined, {
        sensitivity: "base",
      }),
    );

    return result;
  }, [queues, searchQuery]);

  if (queues.length === 0) {
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
        placeholder="Search queues by name or description..."
        prefix={<SearchOutlined />}
        value={searchQuery}
        onChange={(e) => setSearchQuery(e.target.value)}
        style={{ marginBottom: "16px" }}
        allowClear
      />

      {/* Queues List */}
      {filteredAndSortedQueues.length === 0 ? (
        <Empty
          description="No queues match your search"
          image={Empty.PRESENTED_IMAGE_SIMPLE}
        />
      ) : (
        <List
          itemLayout="horizontal"
          dataSource={filteredAndSortedQueues}
          renderItem={(queue) => {
            const actions = renderActions ? renderActions(queue) : null;
            const handleClick = onItemClick ? () => onItemClick(queue) : null;

            return (
              <QueueListItem
                queue={queue}
                actions={actions}
                onClick={handleClick}
                showCreatedDate={showCreatedDate}
                showStats={showStats}
              />
            );
          }}
        />
      )}
    </div>
  );
};

export default QueueList;
