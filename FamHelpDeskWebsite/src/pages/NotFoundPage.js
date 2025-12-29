import React from "react";
import { Result, Button } from "antd";
import { useNavigate } from "react-router-dom";
import { FileTextOutlined } from "@ant-design/icons";

const NotFoundPage = () => {
  const navigate = useNavigate();

  return (
    <div
      style={{
        display: "flex",
        justifyContent: "center",
        alignItems: "center",
        minHeight: "calc(100vh - 64px)",
        padding: "20px",
      }}
    >
      <Result
        icon={
          <div style={{ fontSize: "120px", color: "#faad14" }}>
            <FileTextOutlined style={{ transform: "rotate(-15deg)" }} />
          </div>
        }
        title={
          <div>
            <h1 style={{ fontSize: "72px", margin: "0", color: "#595959" }}>
              404
            </h1>
            <h2
              style={{ fontSize: "24px", margin: "10px 0", color: "#8c8c8c" }}
            >
              Ticket Not Found
            </h2>
          </div>
        }
        subTitle={
          <div style={{ maxWidth: "500px", margin: "0 auto" }}>
            <p
              style={{
                fontSize: "16px",
                color: "#8c8c8c",
                marginBottom: "8px",
              }}
            >
              Oops! This page seems to have wandered off like an unassigned
              ticket.
            </p>
            <p style={{ fontSize: "14px", color: "#bfbfbf" }}>
              Maybe it's stuck in the queue... or someone accidentally marked it
              as "resolved"? 🎫
            </p>
          </div>
        }
        extra={
          <div
            style={{
              display: "flex",
              gap: "12px",
              justifyContent: "center",
              flexWrap: "wrap",
            }}
          >
            <Button type="primary" size="large" onClick={() => navigate("/")}>
              Go Home
            </Button>
            <Button size="large" onClick={() => navigate(-1)}>
              Go Back
            </Button>
          </div>
        }
      />
    </div>
  );
};

export default NotFoundPage;
