import { LightningElement, api, wire } from 'lwc';
import getTicketsByRecordId from '@salesforce/apex/CrmTicketController.getTicketsByRecordId';
import reenviarPdf from '@salesforce/apex/CrmTicketController.reenviarPdf';
import cancelarBilhete from '@salesforce/apex/CrmTicketController.cancelarBilhete';
import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class CrmGestorBilhetesContexto extends LightningElement {
    @api recordId; // ID do Contact ou Account
    
    bilhetesAtivos;
    error;
    wiredBilhetesResult;

    @wire(getTicketsByRecordId, { recordId: '$recordId' })
    wiredBilhetes(result) {
        this.wiredBilhetesResult = result;
        if (result.data) {
            this.bilhetesAtivos = result.data;
            this.error = undefined;
        } else if (result.error) {
            this.error = result.error;
            this.bilhetesAtivos = undefined;
        }
    }

    get temBilhetes() {
        return this.bilhetesAtivos && this.bilhetesAtivos.length > 0;
    }

    async handleReenviarPdf(event) {
        const ticketId = event.target.dataset.id;
        try {
            await reenviarPdf({ ticketId: ticketId });
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Sucesso',
                    message: 'O PDF do bilhete foi colocado na fila de envio.',
                    variant: 'success'
                })
            );
        } catch (error) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Erro no Reenvio',
                    message: error.body.message,
                    variant: 'error'
                })
            );
        }
    }

    async handleCancelar(event) {
        const ticketId = event.target.dataset.id;
        if(confirm(`Tem a certeza que deseja efetuar o cancelamento do bilhete? Esta ação não pode ser revertida.`)) {
            try {
                await cancelarBilhete({ ticketId: ticketId });
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Cancelado',
                        message: 'O bilhete foi cancelado com sucesso.',
                        variant: 'success'
                    })
                );
                await refreshApex(this.wiredBilhetesResult);
            } catch (error) {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Erro ao Cancelar',
                        message: error.body.message,
                        variant: 'error'
                    })
                );
            }
        }
    }
}
