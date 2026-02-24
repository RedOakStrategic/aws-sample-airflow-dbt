#!/usr/bin/env python3
"""Generate HTML test report from Athena elementary_test_results table.
Features similar to dbt Cloud and Elementary dashboards.
"""
import boto3
import time
from datetime import datetime, timezone

athena = boto3.client('athena')
DATABASE = 'lakehouse-mvp_sandbox_lakehouse'
WORKGROUP = 'lakehouse-mvp-sandbox-workgroup'

def run_query(sql):
    """Execute Athena query and return results."""
    response = athena.start_query_execution(
        QueryString=sql,
        QueryExecutionContext={'Database': DATABASE},
        WorkGroup=WORKGROUP
    )
    query_id = response['QueryExecutionId']
    
    while True:
        result = athena.get_query_execution(QueryExecutionId=query_id)
        state = result['QueryExecution']['Status']['State']
        if state in ['SUCCEEDED', 'FAILED', 'CANCELLED']:
            break
        time.sleep(1)
    
    if state != 'SUCCEEDED':
        raise Exception(f"Query failed: {result['QueryExecution']['Status'].get('StateChangeReason')}")
    
    results = athena.get_query_results(QueryExecutionId=query_id)
    rows = results['ResultSet']['Rows']
    
    if len(rows) <= 1:
        return []
    
    headers = [col['VarCharValue'] for col in rows[0]['Data']]
    data = []
    for row in rows[1:]:
        data.append({headers[i]: col.get('VarCharValue', '') for i, col in enumerate(row['Data'])})
    
    return data

def generate_report():
    """Generate HTML report from Athena data."""
    
    # Get latest invocations
    invocations = run_query("""
        SELECT invocation_id, MIN(detected_at) as run_time, COUNT(*) as tests,
               SUM(CASE WHEN status='pass' THEN 1 ELSE 0 END) as passed,
               SUM(CASE WHEN status='fail' THEN 1 ELSE 0 END) as failed
        FROM elementary_test_results
        GROUP BY invocation_id
        ORDER BY run_time DESC
        LIMIT 10
    """)
    
    # Get latest test details
    latest_tests = run_query("""
        SELECT test_name, table_name, test_type, column_name, status, failures, detected_at
        FROM elementary_test_results
        WHERE invocation_id = (
            SELECT invocation_id FROM elementary_test_results 
            ORDER BY detected_at DESC LIMIT 1
        )
        ORDER BY table_name, test_name
    """)
    
    # Get data counts
    counts = run_query("""
        SELECT 'fct_events' as tbl, COUNT(*) as cnt FROM fct_events
        UNION ALL SELECT 'dim_users', COUNT(*) FROM dim_users
        UNION ALL SELECT 'stg_raw_events', COUNT(*) FROM stg_raw_events
        UNION ALL SELECT 'stg_raw_users', COUNT(*) FROM stg_raw_users
    """)
    
    # Get test coverage by model
    coverage = run_query("""
        SELECT table_name, COUNT(DISTINCT test_name) as test_count,
               SUM(CASE WHEN status='pass' THEN 1 ELSE 0 END) as passed,
               SUM(CASE WHEN status='fail' THEN 1 ELSE 0 END) as failed
        FROM elementary_test_results
        WHERE invocation_id = (
            SELECT invocation_id FROM elementary_test_results 
            ORDER BY detected_at DESC LIMIT 1
        )
        GROUP BY table_name
        ORDER BY table_name
    """)
    
    # Get test type breakdown
    test_types = run_query("""
        SELECT test_type, COUNT(*) as count,
               SUM(CASE WHEN status='pass' THEN 1 ELSE 0 END) as passed
        FROM elementary_test_results
        WHERE invocation_id = (
            SELECT invocation_id FROM elementary_test_results 
            ORDER BY detected_at DESC LIMIT 1
        )
        GROUP BY test_type
        ORDER BY count DESC
    """)
    
    # Get test history trend (last 5 runs)
    trend = run_query("""
        SELECT DATE(detected_at) as run_date, 
               COUNT(DISTINCT invocation_id) as runs,
               COUNT(*) as total_tests,
               SUM(CASE WHEN status='pass' THEN 1 ELSE 0 END) as passed
        FROM elementary_test_results
        GROUP BY DATE(detected_at)
        ORDER BY run_date DESC
        LIMIT 7
    """)
    
    # Calculate summary stats
    latest = invocations[0] if invocations else {}
    total_tests = int(latest.get('tests', 0))
    passed = int(latest.get('passed', 0))
    failed = int(latest.get('failed', 0))
    pass_rate = (passed / total_tests * 100) if total_tests > 0 else 0
    
    now = datetime.now(timezone.utc).strftime('%Y-%m-%d %H:%M:%S')
    
    html = f"""<!DOCTYPE html>
<html>
<head>
    <title>Data Lakehouse - Test Dashboard</title>
    <style>
        * {{ box-sizing: border-box; }}
        body {{ 
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; 
            margin: 0; 
            background: #0f1419; 
            color: #e7e9ea;
        }}
        .header {{
            background: linear-gradient(135deg, #1a1a2e 0%, #16213e 100%);
            padding: 30px 40px;
            border-bottom: 1px solid #2d3748;
        }}
        .header h1 {{ margin: 0; font-size: 28px; color: #fff; }}
        .header p {{ margin: 8px 0 0; color: #8899a6; font-size: 14px; }}
        .container {{ max-width: 1400px; margin: 0 auto; padding: 30px 40px; }}
        
        /* Status Banner */
        .status-banner {{
            background: linear-gradient(135deg, #064e3b 0%, #065f46 100%);
            border-radius: 12px;
            padding: 24px 30px;
            margin-bottom: 30px;
            display: flex;
            align-items: center;
            justify-content: space-between;
        }}
        .status-banner.failing {{
            background: linear-gradient(135deg, #7f1d1d 0%, #991b1b 100%);
        }}
        .status-icon {{ font-size: 48px; }}
        .status-text h2 {{ margin: 0; font-size: 24px; }}
        .status-text p {{ margin: 5px 0 0; opacity: 0.8; }}
        .status-stats {{ text-align: right; }}
        .status-stats .big {{ font-size: 36px; font-weight: bold; }}
        
        /* Grid Layout */
        .grid {{ display: grid; grid-template-columns: repeat(auto-fit, minmax(300px, 1fr)); gap: 20px; margin-bottom: 30px; }}
        .grid-2 {{ grid-template-columns: repeat(2, 1fr); }}
        .grid-4 {{ grid-template-columns: repeat(4, 1fr); }}
        
        /* Cards */
        .card {{
            background: #192734;
            border-radius: 12px;
            padding: 24px;
            border: 1px solid #2d3748;
        }}
        .card h3 {{ margin: 0 0 20px; font-size: 16px; color: #8899a6; font-weight: 500; }}
        
        /* Stat Cards */
        .stat-card {{
            background: #192734;
            border-radius: 12px;
            padding: 20px;
            text-align: center;
            border: 1px solid #2d3748;
        }}
        .stat-value {{ font-size: 32px; font-weight: bold; color: #fff; }}
        .stat-label {{ color: #8899a6; margin-top: 8px; font-size: 14px; }}
        .stat-card.success .stat-value {{ color: #10b981; }}
        .stat-card.warning .stat-value {{ color: #f59e0b; }}
        .stat-card.danger .stat-value {{ color: #ef4444; }}
        .stat-card.info .stat-value {{ color: #3b82f6; }}
        
        /* Tables */
        table {{ width: 100%; border-collapse: collapse; }}
        th {{ 
            text-align: left; 
            padding: 12px 16px; 
            background: #1e2d3d; 
            color: #8899a6; 
            font-weight: 500;
            font-size: 12px;
            text-transform: uppercase;
            letter-spacing: 0.5px;
        }}
        td {{ 
            padding: 14px 16px; 
            border-bottom: 1px solid #2d3748;
            font-size: 14px;
        }}
        tr:hover {{ background: #1e2d3d; }}
        
        /* Badges */
        .badge {{
            display: inline-block;
            padding: 4px 10px;
            border-radius: 20px;
            font-size: 12px;
            font-weight: 600;
        }}
        .badge-pass {{ background: #064e3b; color: #10b981; }}
        .badge-fail {{ background: #7f1d1d; color: #ef4444; }}
        .badge-type {{ background: #1e3a5f; color: #60a5fa; }}
        
        /* Progress Bar */
        .progress-bar {{
            height: 8px;
            background: #2d3748;
            border-radius: 4px;
            overflow: hidden;
            margin-top: 10px;
        }}
        .progress-fill {{
            height: 100%;
            background: linear-gradient(90deg, #10b981 0%, #34d399 100%);
            border-radius: 4px;
            transition: width 0.3s ease;
        }}
        
        /* Model Coverage */
        .model-item {{
            display: flex;
            justify-content: space-between;
            align-items: center;
            padding: 12px 0;
            border-bottom: 1px solid #2d3748;
        }}
        .model-item:last-child {{ border-bottom: none; }}
        .model-name {{ font-weight: 500; }}
        .model-stats {{ display: flex; gap: 15px; align-items: center; }}
        
        /* Timeline */
        .timeline-item {{
            display: flex;
            align-items: center;
            padding: 10px 0;
            border-bottom: 1px solid #2d3748;
        }}
        .timeline-item:last-child {{ border-bottom: none; }}
        .timeline-dot {{
            width: 10px;
            height: 10px;
            border-radius: 50%;
            background: #10b981;
            margin-right: 15px;
        }}
        .timeline-dot.fail {{ background: #ef4444; }}
        .timeline-content {{ flex: 1; }}
        .timeline-time {{ color: #8899a6; font-size: 12px; }}
        
        /* Tabs */
        .tabs {{ display: flex; gap: 10px; margin-bottom: 20px; }}
        .tab {{
            padding: 10px 20px;
            background: #1e2d3d;
            border-radius: 8px;
            cursor: pointer;
            font-size: 14px;
            border: 1px solid transparent;
        }}
        .tab.active {{ background: #2d4a6f; border-color: #3b82f6; }}
        
        code {{ 
            background: #1e2d3d; 
            padding: 2px 8px; 
            border-radius: 4px; 
            font-family: 'SF Mono', Monaco, monospace;
            font-size: 13px;
        }}
        
        .footer {{
            text-align: center;
            padding: 30px;
            color: #8899a6;
            font-size: 13px;
            border-top: 1px solid #2d3748;
            margin-top: 40px;
        }}
    </style>
</head>
<body>
    <div class="header">
        <h1>🏠 Data Lakehouse Test Dashboard</h1>
        <p>Last updated: {now} UTC • Database: {DATABASE}</p>
    </div>
    
    <div class="container">
        <!-- Status Banner -->
        <div class="status-banner {'failing' if failed > 0 else ''}">
            <div style="display: flex; align-items: center; gap: 20px;">
                <div class="status-icon">{'✅' if failed == 0 else '❌'}</div>
                <div class="status-text">
                    <h2>{'All Tests Passing' if failed == 0 else f'{failed} Tests Failing'}</h2>
                    <p>Latest run: {latest.get('run_time', 'N/A')[:19]} UTC</p>
                </div>
            </div>
            <div class="status-stats">
                <div class="big">{pass_rate:.0f}%</div>
                <div>Pass Rate</div>
            </div>
        </div>
        
        <!-- Summary Stats -->
        <div class="grid grid-4">
            <div class="stat-card info">
                <div class="stat-value">{total_tests}</div>
                <div class="stat-label">Total Tests</div>
            </div>
            <div class="stat-card success">
                <div class="stat-value">{passed}</div>
                <div class="stat-label">Passed</div>
            </div>
            <div class="stat-card {'danger' if failed > 0 else 'success'}">
                <div class="stat-value">{failed}</div>
                <div class="stat-label">Failed</div>
            </div>
            <div class="stat-card info">
                <div class="stat-value">{len(invocations)}</div>
                <div class="stat-label">Total Runs</div>
            </div>
        </div>
        
        <!-- Data Assets & Test Coverage -->
        <div class="grid grid-2">
            <div class="card">
                <h3>📊 Data Assets</h3>
"""
    
    for c in counts:
        html += f"""                <div class="model-item">
                    <span class="model-name"><code>{c['tbl']}</code></span>
                    <span>{int(c['cnt']):,} rows</span>
                </div>
"""
    
    html += """            </div>
            
            <div class="card">
                <h3>🎯 Test Coverage by Model</h3>
"""
    
    for cov in coverage:
        total = int(cov['passed']) + int(cov['failed'])
        pct = (int(cov['passed']) / total * 100) if total > 0 else 0
        html += f"""                <div class="model-item">
                    <div>
                        <span class="model-name"><code>{cov['table_name']}</code></span>
                        <div class="progress-bar" style="width: 150px;">
                            <div class="progress-fill" style="width: {pct}%;"></div>
                        </div>
                    </div>
                    <div class="model-stats">
                        <span class="badge badge-pass">{cov['passed']} pass</span>
                        {'<span class="badge badge-fail">' + cov['failed'] + ' fail</span>' if int(cov['failed']) > 0 else ''}
                    </div>
                </div>
"""
    
    html += """            </div>
        </div>
        
        <!-- Test Types & Run History -->
        <div class="grid grid-2">
            <div class="card">
                <h3>🔍 Test Types</h3>
                <table>
                    <tr><th>Type</th><th>Count</th><th>Passed</th></tr>
"""
    
    for tt in test_types:
        html += f"""                    <tr>
                        <td><span class="badge badge-type">{tt['test_type']}</span></td>
                        <td>{tt['count']}</td>
                        <td><span class="badge badge-pass">{tt['passed']}</span></td>
                    </tr>
"""
    
    html += """                </table>
            </div>
            
            <div class="card">
                <h3>📈 Run History</h3>
"""
    
    for inv in invocations[:5]:
        has_failures = int(inv['failed']) > 0
        html += f"""                <div class="timeline-item">
                    <div class="timeline-dot {'fail' if has_failures else ''}"></div>
                    <div class="timeline-content">
                        <div><code>{inv['invocation_id'][:12]}...</code></div>
                        <div class="timeline-time">{inv['run_time'][:19]}</div>
                    </div>
                    <div>
                        <span class="badge badge-pass">{inv['passed']}</span>
                        {f'<span class="badge badge-fail">{inv["failed"]}</span>' if has_failures else ''}
                    </div>
                </div>
"""
    
    html += """            </div>
        </div>
        
        <!-- Detailed Test Results -->
        <div class="card">
            <h3>📋 Latest Test Results</h3>
            <table>
                <tr>
                    <th>Test Name</th>
                    <th>Model</th>
                    <th>Column</th>
                    <th>Type</th>
                    <th>Status</th>
                    <th>Time</th>
                </tr>
"""
    
    for test in latest_tests:
        status_badge = 'badge-pass' if test['status'] == 'pass' else 'badge-fail'
        html += f"""                <tr>
                    <td><code>{test['test_name']}</code></td>
                    <td>{test['table_name']}</td>
                    <td>{test['column_name'] or '-'}</td>
                    <td><span class="badge badge-type">{test['test_type']}</span></td>
                    <td><span class="badge {status_badge}">{test['status'].upper()}</span></td>
                    <td class="timeline-time">{test['detected_at'][11:19]}</td>
                </tr>
"""
    
    html += f"""            </table>
        </div>
        
        <div class="footer">
            <p>Data Lakehouse MVP • Powered by AWS Lambda + Athena + Iceberg</p>
            <p>Source: <code>elementary_test_results</code> table in Athena</p>
        </div>
    </div>
</body>
</html>"""
    
    return html

if __name__ == "__main__":
    print("Generating dashboard from Athena...")
    html = generate_report()
    
    with open('athena_test_report.html', 'w') as f:
        f.write(html)
    
    print("Dashboard saved to athena_test_report.html")
