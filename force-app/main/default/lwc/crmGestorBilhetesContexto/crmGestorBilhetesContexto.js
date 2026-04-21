import { LightningElement, api } from 'lwc';

export default class CrmGestorBilhetesContexto extends LightningElement {
    @api recordId; // ID do Contact ou Account
    
    // Dados para demonstração (substituir por @wire que chame método Apex depois)
    bilhetesAtivos = [
        {
            id: 'TKT-001',
            eventoNome: 'FCP vs Benfica - Liga Portugal',
            data: '24 de Maio, 2026 - 20:30',
            lugar: 'Bancada Sul - Fila 8 - Lugar 12',
            status: 'Válido',
            statusClass: 'badge success',
            isValido: true,
            codigo: 'X39B-JHQ2'
        },
        {
            id: 'TKT-002',
            eventoNome: 'FCP vs Benfica - Liga Portugal',
            data: '24 de Maio, 2026 - 20:30',
            lugar: 'Bancada Sul - Fila 8 - Lugar 13',
            status: 'Cancelado',
            statusClass: 'badge neutral',
            isValido: false,
            codigo: 'P9ZN-2L0A'
        }
    ];

    get temBilhetes() {
        return this.bilhetesAtivos && this.bilhetesAtivos.length > 0;
    }

    handleReenviarPdf(event) {
        const ticketId = event.target.dataset.id;
        // Invocaria Action ou Apex aqui
        alert(`O PDF do bilhete ${ticketId} foi colocado na fila de envio com sucesso!`);
    }

    handleCancelar(event) {
        const ticketId = event.target.dataset.id;
        if(confirm(`Tem a certeza que deseja efetuar o cancelamento do bilhete ${ticketId}? Esta ação não pode ser revertida.`)) {
            alert('Bilhete cancelado! A atualizar backend...');
        }
    }
}
