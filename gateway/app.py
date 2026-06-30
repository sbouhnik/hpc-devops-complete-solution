from flask import Flask, Response, request, jsonify
import sys

app = Flask(__name__)
metrics = {}

@app.put('/update-metric')
def update_metric():
    payload = request.get_json(force=True)
    name = payload['metric']
    value = float(payload['value'])
    labels = payload.get('labels', {})
    key = (name, tuple(sorted((str(k), str(v)) for k, v in labels.items())))
    metrics[key] = value
    return jsonify(status='ok')

@app.get('/metrics')
def export_metrics():
    lines = []
    for (name, labels), value in sorted(metrics.items()):
        label_text = ','.join(f'{k}="{v}"' for k, v in labels)
        lines.append(f'{name}{{{label_text}}} {value}')
    return Response('\n'.join(lines) + '\n', mimetype='text/plain; version=0.0.4')

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8080)
