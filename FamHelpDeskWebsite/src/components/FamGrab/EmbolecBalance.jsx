import React from "react";
import { Card, Statistic, Space, Spin, Alert } from "antd";
import {
  WalletOutlined,
  ArrowUpOutlined,
  ArrowDownOutlined,
} from "@ant-design/icons";
import { useBalance } from "../../hooks/useFamGrab";

const EmbolecBalance = ({ familyId }) => {
  const { balance, isBalanceFetching, isBalanceError } = useBalance(familyId);

  if (isBalanceFetching && !balance) {
    return (
      <Card>
        <div style={{ textAlign: "center", padding: "20px" }}>
          <Spin />
        </div>
      </Card>
    );
  }

  if (isBalanceError) {
    return (
      <Alert
        message="Failed to load balance"
        type="error"
        showIcon
        style={{ marginBottom: "16px" }}
      />
    );
  }

  if (!balance) return null;

  return (
    <Card>
      <Space size="large" wrap>
        <Statistic
          title="Current Balance"
          value={balance.balance}
          prefix={<WalletOutlined />}
          suffix="Embolecs"
        />
        <Statistic
          title="Total Earned"
          value={balance.total_earned}
          prefix={<ArrowUpOutlined />}
          valueStyle={{ color: "#3f8600" }}
        />
        <Statistic
          title="Total Spent"
          value={balance.total_spent}
          prefix={<ArrowDownOutlined />}
          valueStyle={{ color: "#cf1322" }}
        />
      </Space>
    </Card>
  );
};

export default EmbolecBalance;
