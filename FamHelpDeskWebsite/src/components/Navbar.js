import React from "react";
import { Layout } from "antd";

const { Header } = Layout;

const Navbar = () => {
  return (
    <Header
      style={{
        position: "fixed",
        top: 0,
        zIndex: 1,
        width: "100%",
        display: "flex",
        alignItems: "center",
        backgroundColor: "#001529",
        padding: "0 50px",
      }}
    >
      <div
        style={{
          color: "white",
          fontSize: "20px",
          fontWeight: "bold",
        }}
      >
        Fam Help Desk
      </div>
    </Header>
  );
};

export default Navbar;
