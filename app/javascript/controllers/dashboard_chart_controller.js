import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { data: Array }

  connect() {
    this.renderChart()
  }

  renderChart() {
    const ctx = this.element.getContext('2d')
    const labels = this.dataValue.map(d => d.date)
    const values = this.dataValue.map(d => d.revenue)

    new Chart(ctx, {
      type: 'line',
      data: {
        labels: labels,
        datasets: [{
          label: 'Revenue (Rp)',
          data: values,
          borderColor: '#4f46e5',
          backgroundColor: 'rgba(79, 70, 229, 0.1)',
          fill: true,
          tension: 0.4,
          pointRadius: 4,
          pointBackgroundColor: '#4f46e5'
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          legend: { display: false }
        },
        scales: {
          y: {
            beginAtZero: true,
            grid: { color: '#f3f4f6' },
            ticks: {
              callback: function(value) {
                return 'Rp ' + new Intl.NumberFormat('id-ID').format(value)
              }
            }
          },
          x: {
            grid: { display: false }
          }
        }
      }
    })
  }
}
