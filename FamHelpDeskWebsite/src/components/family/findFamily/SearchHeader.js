import React from "react";
import { Card, Typography, Space, Input } from "antd";
import { SearchOutlined } from "@ant-design/icons";

const { Title, Text } = Typography;
const { Search } = Input;

/**
 * Shared header component for FindFamily pages
 * Desktop version - larger text and spacing
 */
const SearchHeaderDesktop = ({ searchQuery, setSearchQuery }) => {
  return (
    <Card>
      <Space direction="vertical" size="middle" style={{ width: "100%" }}>
        <div
          style={{
            display: "flex",
            alignItems: "center",
            gap: "12px",
          }}
        >
          <SearchOutlined style={{ fontSize: "32px" }} />
          <Title level={2} style={{ margin: 0 }}>
            Find a Family
          </Title>
        </div>

        <Text type="secondary" style={{ fontSize: "16px" }}>
          Search for families to join. Request membership and wait for an admin
          to approve your request.
        </Text>

        <Search
          placeholder="Search families by name or description"
          allowClear
          enterButton
          size="large"
          value={searchQuery}
          onChange={(e) => setSearchQuery(e.target.value)}
          prefix={<SearchOutlined />}
        />
      </Space>
    </Card>
  );
};

/**
 * Shared header component for FindFamily pages
 * Mobile version - compact text and spacing
 */
const SearchHeaderMobile = ({ searchQuery, setSearchQuery }) => {
  return (
    <Card bodyStyle={{ padding: "12px" }}>
      <Space direction="vertical" size="small" style={{ width: "100%" }}>
        <div
          style={{
            display: "flex",
            alignItems: "center",
            gap: "8px",
          }}
        >
          <SearchOutlined style={{ fontSize: "20px" }} />
          <Title level={4} style={{ margin: 0, fontSize: "16px" }}>
            Find a Family
          </Title>
        </div>

        <Text type="secondary" style={{ fontSize: "12px", lineHeight: "1.4" }}>
          Search for families to join. Request membership and wait for an admin
          to approve your request.
        </Text>

        <Search
          placeholder="Search families..."
          allowClear
          enterButton
          size="middle"
          value={searchQuery}
          onChange={(e) => setSearchQuery(e.target.value)}
          prefix={<SearchOutlined />}
          style={{ fontSize: "12px" }}
        />
      </Space>
    </Card>
  );
};

export { SearchHeaderDesktop, SearchHeaderMobile };
