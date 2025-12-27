import React, { useContext } from "react";
import { Layout, Button, Avatar } from "antd";
import { UserOutlined, TagsOutlined } from "@ant-design/icons";
import { useNavigate } from "react-router-dom";
import { UserAuthenticationContext } from "../provider/UserAuthenticationProvider";

const { Header } = Layout;

const Navbar = () => {
  const navigate = useNavigate();
  const { isAuthenticated } = useContext(UserAuthenticationContext);

  return (
    <Header
      style={{
        position: "fixed",
        top: 0,
        zIndex: 1,
        width: "100%",
        display: "flex",
        alignItems: "center",
        justifyContent: "space-between",
        backgroundColor: "#001529",
        padding: "0 50px",
      }}
    >
      <div
        style={{
          display: "flex",
          alignItems: "center",
          gap: "12px",
          color: "white",
          fontSize: "20px",
          fontWeight: "bold",
          cursor: "pointer",
        }}
        onClick={() => navigate("/")}
      >
        <TagsOutlined style={{ fontSize: "24px" }} />
        <span>Fam Help Desk</span>
      </div>

      {isAuthenticated && (
        <Button
          type="text"
          icon={<Avatar icon={<UserOutlined />} size="small" />}
          onClick={() => navigate("/profile")}
          style={{ color: "white" }}
        />
      )}
    </Header>
  );
};

export default Navbar;
