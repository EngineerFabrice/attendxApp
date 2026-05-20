import { useEffect, useState } from "react";
import { Download, FileText, AlertTriangle, Bell, Loader2 } from "lucide-react";
import {
  BarChart,
  Bar,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  ResponsiveContainer,
} from "recharts";
import api from "../services/api";

export default function Reports() {
  const [students, setStudents] = useState([]);
  const [sessions, setSessions] = useState([]);
  const [loading, setLoading] = useState(true);
  const [sendingWarning, setSendingWarning] = useState(null);
  const [sendingBulk, setSendingBulk] = useState(false);
  useEffect(() => {
    Promise.all([api.get("/lecturer/students"), api.get("/lecturer/sessions")])
      .then(([s, sess]) => {
        let studentsRaw = [];
        if (Array.isArray(s.data)) {
          studentsRaw = s.data;
        } else if (s.data?.data && Array.isArray(s.data.data)) {
          studentsRaw = s.data.data;
        } else if (s.data?.students && Array.isArray(s.data.students)) {
          studentsRaw = s.data.students;
        }

        const normalizedStudents = studentsRaw.map((student) => ({
          id: student.id || student.student_id,
          fullName: student.fullName || student.full_name,
          regNumber: student.regNumber || student.reg_number,
          course: student.course || student.course_name || student.courseName,
          attendanceRate: student.attendanceRate || student.attendance_rate || 0,
          email: student.email,
          phone: student.phone,
        }));

        setStudents(normalizedStudents);
        setSessions(sess.data?.data || []);
        setLoading(false);
      })
      .catch(() => setLoading(false));
  }, []);

  const handleSendWarning = async (student) => {
    try {
      setSendingWarning(student.id);

      if (!student.id) {
        alert(`Cannot send warning: Missing student ID`);
        return;
      }

      if (!student.attendanceRate && student.attendanceRate !== 0) {
        alert(`Cannot send warning: Missing attendance rate for ${student.fullName}`);
        return;
      }

      if (!student.course) {
        alert(`Cannot send warning: Missing course information for ${student.fullName}`);
        return;
      }

      const response = await api.post("/notifications/send-warning", {
        studentId: student.id,
        studentName: student.fullName,
        attendanceRate: student.attendanceRate,
        courseName: student.course,
      });

      if (response.data.success) {
        alert(`⚠️ Warning sent to ${student.fullName}`);

        setStudents((prevStudents) =>
          prevStudents.map((s) =>
            s.id === student.id
              ? { ...s, warningSent: true, lastWarningSent: new Date() }
              : s,
          ),
        );
      }
    } catch (error) {
      console.error("Error sending warning:", error);
      alert(
        `Failed to send warning to ${student.fullName}. ${error.response?.data?.error || error.message}`,
      );
    } finally {
      setSendingWarning(null);
    }
  };

  const handleSendBulkWarnings = async () => {
    const atRiskStudents = students.filter((s) => s.attendanceRate < 75);

    if (atRiskStudents.length === 0) {
      alert("No at-risk students found");
      return;
    }

    if (
      !confirm(`Send warnings to ${atRiskStudents.length} at-risk students?`)
    ) {
      return;
    }

    setSendingBulk(true);

    try {
      const response = await api.post("/notifications/send-bulk-warnings", {
        students: atRiskStudents.map((s) => ({
          id: s.id,
          fullName: s.fullName,
          attendanceRate: s.attendanceRate,
          course: s.course,
        })),
      });

      if (response.data.success) {
        alert(
          `✅ Sent ${response.data.success} warnings\n❌ Failed: ${response.data.failed}`,
        );
      }
    } catch (error) {
      console.error("Error sending bulk warnings:", error);
      alert("Failed to send bulk warnings");
    } finally {
      setSendingBulk(false);
    }
  };

  function exportCSV() {
    const headers = "Student,RegNumber,Course,AttendanceRate,Status";
    const rows = students.map(
      (s) =>
        `"${s.fullName}",${s.regNumber || ""},${s.course},${s.attendanceRate}%,${s.attendanceRate >= 75 ? "Good" : "At Risk"}`,
    );
    const csv = [headers, ...rows].join("\n");
    const blob = new Blob([csv], { type: "text/csv" });
    const url = URL.createObjectURL(blob);
    const a = document.createElement("a");
    a.href = url;
    a.download = "attendance_report.csv";
    a.click();
    URL.revokeObjectURL(url);
  }

  const chartData = students.map((s) => ({
    name: s.fullName ? s.fullName.split(" ")[0] : "Student",
    rate: s.attendanceRate || 0,
  }));

  const atRisk = students.filter((s) => (s.attendanceRate || 0) < 75);
  const closedSessions = sessions.filter((s) => s.status === "closed");
  const avgAttendance =
    sessions.length > 0
      ? Math.round(
          closedSessions.reduce(
            (sum, s) => sum + (s.presentCount / s.totalStudents) * 100,
            0,
          ) / (closedSessions.length || 1),
        )
      : 0;

  function exportPDF() {
    const html = `<!DOCTYPE html><html><head><title>Attendance Report</title>
<style>
  body{font-family:Arial,sans-serif;padding:24px;color:#1e293b}
  h1{font-size:20px;margin:0 0 4px}
  .sub{color:#64748b;font-size:13px;margin-bottom:20px}
  .stats{display:flex;gap:16px;margin-bottom:24px}
  .stat{border:1px solid #e2e8f0;padding:12px 20px;border-radius:8px;min-width:140px}
  .stat-label{font-size:12px;color:#64748b}
  .stat-val{font-size:24px;font-weight:700;margin-top:2px}
  .red{color:#dc2626} .green{color:#059669}
  h2{font-size:14px;font-weight:600;margin:20px 0 8px;border-bottom:1px solid #e2e8f0;padding-bottom:4px}
  table{width:100%;border-collapse:collapse;font-size:13px}
  th{text-align:left;padding:7px 10px;border-bottom:2px solid #e2e8f0;color:#64748b;font-weight:600}
  td{padding:7px 10px;border-bottom:1px solid #f1f5f9}
  @media print{body{padding:0}}
</style></head><body>
<h1>Attendance Report</h1>
<div class="sub">Generated on ${new Date().toLocaleDateString("en-GB", { day: "numeric", month: "long", year: "numeric" })}</div>
<div class="stats">
  <div class="stat"><div class="stat-label">Avg. Session Attendance</div><div class="stat-val">${avgAttendance}%</div></div>
  <div class="stat"><div class="stat-label">Total Sessions</div><div class="stat-val">${closedSessions.length}</div></div>
  <div class="stat"><div class="stat-label">At-Risk Students</div><div class="stat-val red">${atRisk.length}</div></div>
</div>
<h2>Student Attendance</h2>
<table><thead><tr><th>Student</th><th>Reg Number</th><th>Course</th><th>Rate</th><th>Status</th></tr></thead><tbody>
${students.map((s) => `<tr><td>${s.fullName || "-"}</td><td>${s.regNumber || "-"}</td><td>${s.course || "-"}</td><td class="${(s.attendanceRate || 0) >= 75 ? "green" : "red"}">${s.attendanceRate || 0}%</td><td>${(s.attendanceRate || 0) >= 75 ? "Good" : "At Risk"}</td></tr>`).join("")}
</tbody></table>
<h2>Session History</h2>
<table><thead><tr><th>Course</th><th>Date</th><th>Present / Total</th><th>Rate</th></tr></thead><tbody>
${closedSessions.map((s) => { const r = Math.round(((s.presentCount || s.present_count || 0) / (s.totalStudents || s.total_students || 1)) * 100); return `<tr><td>${s.course?.name || s.course_name || "Unknown"}</td><td>${new Date(s.startedAt || s.started_at).toLocaleDateString()}</td><td>${s.presentCount || s.present_count || 0} / ${s.totalStudents || s.total_students || 0}</td><td class="${r >= 75 ? "green" : "red"}">${r}%</td></tr>`; }).join("")}
</tbody></table>
</body></html>`;
    const w = window.open("", "_blank", "width=900,height=650");
    w.document.write(html);
    w.document.close();
    w.focus();
    w.print();
  }

  if (loading)
    return (
      <div className="flex justify-center py-20 text-slate-400">Loading…</div>
    );

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-xl font-bold text-slate-800">Reports</h2>
          <p className="text-slate-500 text-sm mt-1">
            Attendance summaries and at-risk analysis
          </p>
        </div>
        <div className="flex items-center gap-3">
          {atRisk.length > 0 && (
            <button
              onClick={handleSendBulkWarnings}
              disabled={sendingBulk}
              className="px-4 py-2 bg-orange-500 text-white rounded-lg hover:bg-orange-600 transition-colors flex items-center gap-2 disabled:opacity-50"
            >
              {sendingBulk ? (
                <>
                  <Loader2 size={16} className="animate-spin" />
                  Sending...
                </>
              ) : (
                <>
                  <Bell size={16} />
                  Send to All ({atRisk.length})
                </>
              )}
            </button>
          )}
          <button
            onClick={exportPDF}
            className="px-4 py-2 border border-slate-200 bg-white text-slate-700 rounded-lg hover:bg-slate-50 transition-colors flex items-center gap-2"
          >
            <FileText size={16} /> Export PDF
          </button>
          <button
            onClick={exportCSV}
            className="btn-primary flex items-center gap-2"
          >
            <Download size={16} /> Export CSV
          </button>
        </div>
      </div>

      {/* Summary cards */}
      <div className="grid grid-cols-3 gap-4">
        <div className="bg-white rounded-2xl p-5 shadow-sm border border-slate-100">
          <p className="text-slate-500 text-sm">Avg. Session Attendance</p>
          <p className="text-3xl font-bold text-slate-800 mt-1">
            {avgAttendance}%
          </p>
        </div>
        <div className="bg-white rounded-2xl p-5 shadow-sm border border-slate-100">
          <p className="text-slate-500 text-sm">Total Sessions</p>
          <p className="text-3xl font-bold text-slate-800 mt-1">
            {closedSessions.length}
          </p>
        </div>
        <div className="bg-white rounded-2xl p-5 shadow-sm border border-slate-100">
          <p className="text-slate-500 text-sm">At-Risk Students</p>
          <p className="text-3xl font-bold text-red-600 mt-1">
            {atRisk.length}
          </p>
        </div>
      </div>

      {/* Chart */}
      <div className="bg-white rounded-2xl p-5 shadow-sm border border-slate-100">
        <h3 className="font-semibold text-slate-800 mb-4">
          Student Attendance Rates
        </h3>
        <ResponsiveContainer width="100%" height={220}>
          <BarChart data={chartData}>
            <CartesianGrid strokeDasharray="3 3" stroke="#f1f5f9" />
            <XAxis dataKey="name" tick={{ fontSize: 12, fill: "#2664eb" }} />
            <YAxis
              domain={[0, 100]}
              unit="%"
              tick={{ fontSize: 12, fill: "#94a3b8" }}
            />
            <Tooltip formatter={(v) => `${v}%`} />
            <Bar dataKey="rate" fill="#10b981" radius={[4, 4, 0, 0]} />
          </BarChart>
        </ResponsiveContainer>
      </div>

      {/* At-risk table */}
      {atRisk.length > 0 && (
        <div className="bg-white rounded-2xl p-5 shadow-sm border border-slate-100">
          <div className="flex items-center gap-2 mb-4">
            <AlertTriangle size={18} className="text-orange-500" />
            <h3 className="font-semibold text-slate-800">
              At-Risk Students (below 75%)
            </h3>
          </div>
          <table className="w-full">
            <thead>
              <tr className="border-b border-slate-100">
                <th className="th">Student</th>
                <th className="th">Course</th>
                <th className="th">Attendance Rate</th>
                <th className="th">Action Needed</th>
              </tr>
            </thead>
            <tbody>
              {atRisk.map((s) => (
                <tr key={s.id} className="border-b border-slate-50">
                  <td className="td font-medium text-slate-800">
                    {s.fullName}
                  </td>
                  <td className="td">
                    <span className="badge badge-blue">{s.course}</span>
                  </td>
                  <td className="td">
                    <span className="text-red-600 font-bold">
                      {s.attendanceRate}%
                    </span>
                  </td>
                  <td className="td">
                    <button
                      onClick={() => handleSendWarning(s)}
                      disabled={sendingWarning === s.id}
                      className="inline-flex items-center gap-2 px-3 py-1.5 bg-orange-500 text-white text-sm rounded-lg hover:bg-orange-600 transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
                    >
                      {sendingWarning === s.id ? (
                        <>
                          <Loader2 size={14} className="animate-spin" />
                          Sending...
                        </>
                      ) : (
                        <>
                          <Bell size={14} />
                          Send Warning
                        </>
                      )}
                    </button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}

      {/* Session history */}
      <div className="bg-white rounded-2xl shadow-sm border border-slate-100 overflow-hidden">
        <div className="px-5 py-4 border-b border-slate-100">
          <h3 className="font-semibold text-slate-800">Session History</h3>
        </div>
        <table className="w-full">
          <thead>
            <tr className="border-b border-slate-100">
              <th className="th">Course</th>
              <th className="th">Date</th>
              <th className="th">Present / Total</th>
              <th className="th">Rate</th>
            </tr>
          </thead>
          <tbody>
            {closedSessions.map((s) => {
              const rate = Math.round((s.presentCount / s.totalStudents) * 100);
              return (
                <tr
                  key={s.id}
                  className="border-b border-slate-50 hover:bg-slate-50"
                >
                  <td className="td font-medium text-slate-800">
                    {s.course?.name || s.course_name || "Unknown"}
                  </td>
                  <td className="td text-slate-500">
                    {new Date(s.startedAt || s.started_at).toLocaleDateString()}
                  </td>
                  <td className="td">
                    {s.presentCount || s.present_count} /{" "}
                    {s.totalStudents || s.total_students}
                  </td>
                  <td className="td">
                    <div className="flex items-center gap-2">
                      <div className="flex-1 h-2 bg-slate-100 rounded-full overflow-hidden max-w-20">
                        <div
                          className={`h-full rounded-full ${rate >= 75 ? "bg-emerald-500" : "bg-red-500"}`}
                          style={{ width: `${rate}%` }}
                        />
                      </div>
                      <span
                        className={`font-semibold text-sm ${rate >= 75 ? "text-emerald-600" : "text-red-600"}`}
                      >
                        {rate}%
                      </span>
                    </div>
                  </td>
                </tr>
              );
            })}
          </tbody>
        </table>
      </div>
    </div>
  );
}
