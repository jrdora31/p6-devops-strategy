import { DatePipe, NgClass, NgFor, NgIf, UpperCasePipe } from '@angular/common';
import { Component, OnInit } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { RouterLink } from '@angular/router';
import { Person, PersonService } from '../person.service';
import { Organization, OrganizationService } from '../organization.service';

interface DeploymentInfo {
  environment: string;
  track: string;
  version: string;
}

@Component({
  selector: 'app-main-dashboard',
  standalone: true,
  imports: [RouterLink, NgFor, NgIf, NgClass, DatePipe, UpperCasePipe],
  templateUrl: './main-dashboard.component.html',
  styleUrl: './main-dashboard.component.css'
})
export class MainDashboardComponent implements OnInit {
  organizations: Organization[] = [];
  persons: Person[] = [];
  deployment: DeploymentInfo = {
    environment: 'unknown',
    track: 'unknown',
    version: 'version unavailable'
  };

  constructor(
    private personService: PersonService,
    private organizationService: OrganizationService,
    private http: HttpClient
  ) { }


  ngOnInit(): void {
    this.personService.fetchAll().then(persons => this.persons = persons);
    this.organizationService.fetchAll().then(orgs => this.organizations = orgs);
    this.http.get<DeploymentInfo>('/api/deployment-info').subscribe({
      next: deployment => this.deployment = deployment,
      // Le tableau de bord reste utilisable si l'information de déploiement
      // est momentanément indisponible ; le bandeau signale alors cet état.
      error: () => this.deployment.version = 'version unavailable'
    });
  }
}

