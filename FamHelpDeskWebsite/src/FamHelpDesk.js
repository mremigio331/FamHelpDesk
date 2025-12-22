import React from "react";
import { BrowserRouter as Router, Routes, Route } from "react-router-dom";
import { Layout } from "antd";
import Home from "./pages/home/Home";
import Navbar from "./components/Navbar";

const { Content } = Layout;

const FamHelpDesk = () => {
  return (
    <Router>
      <Layout style={{ minHeight: "100vh" }}>
        <Navbar />
        <Content style={{ marginTop: "64px" }}>
          <Routes>
            <Route path="/" element={<Home />} />
          </Routes>
        </Content>
      </Layout>
    </Router>
  );
};

export default FamHelpDesk;
