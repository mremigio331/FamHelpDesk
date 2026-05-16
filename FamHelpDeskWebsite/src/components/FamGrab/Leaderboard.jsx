import React from "react";
import { useNavigate } from "react-router-dom";
import { Table, Typography, Spin, Alert, Tag } from "antd";
import { TrophyOutlined } from "@ant-design/icons";
import { useLeaderboard } from "../../hooks/useFamGrab";

const { Title } = Typography;

const getRankStyle = (index) => {
  switch (index) {
    case 0:
      return { color: "#faad14", fontWeight: "bold" }; // Gold
    case 1:
      return { color: "#8c8c8c", fontWeight: "bold" }; // Silver
    case 2:
      return { color: "#d48806", fontWeight: "bold" }; // Bronze
    default:
      return {};
  }
};

const Leaderboard = ({ familyId }) => {
  const navigate = useNavigate();
  const { leaderboard, isLeaderboardFetching, isLeaderboardError } =
    useLeaderboard(familyId);

  if (isLeaderboardFetching && leaderboard.length === 0) {
    return (
      <div style={{ textAlign: "center", padding: "40px" }}>
        <Spin size="large" />
      </div>
    );
  }

  if (isLeaderboardError) {
    return (
      <Alert
        message="Failed to load leaderboard"
        type="error"
        showIcon
      />
    );
  }

  const columns = [
    {
      title: "Rank",
      key: "rank",
      width: 70,
      render: (_, __, index) => (
        <span style={getRankStyle(index)}>
          {index === 0 && <TrophyOutlined style={{ marginRight: 4 }} />}
          #{index + 1}
        </span>
      ),
    },
    {
      title: "Member",
      dataIndex: "user_id",
      key: "user_id",
      render: (userId) => userId,
    },
    {
      title: "Total Earned",
      dataIndex: "total_earned",
      key: "total_earned",
      render: (value) => (
        <Tag color="green">{value || 0} Embolecs</Tag>
      ),
      sorter: (a, b) => (a.total_earned || 0) - (b.total_earned || 0),
      defaultSortOrder: "descend",
    },
    {
      title: "Items Fulfilled",
      dataIndex: "fulfillment_count",
      key: "fulfillment_count",
      render: (value) => value || 0,
    },
    {
      title: "This Month",
      dataIndex: "monthly_earnings",
      key: "monthly_earnings",
      render: (value) => (
        <span>{value || 0} Embolecs</span>
      ),
    },
  ];

  return (
    <div>
      <Title level={4}>
        <TrophyOutlined /> Leaderboard
      </Title>
      <Table
        dataSource={leaderboard}
        columns={columns}
        rowKey="user_id"
        pagination={false}
        size="middle"
        onRow={(record) => ({
          onClick: () => navigate(`/family/${familyId}/grab/reviews/${record.user_id}`),
          style: { cursor: "pointer" },
        })}
      />
    </div>
  );
};

export default Leaderboard;
