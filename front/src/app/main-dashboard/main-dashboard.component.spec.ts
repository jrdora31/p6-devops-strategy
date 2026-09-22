import { ComponentFixture, TestBed } from '@angular/core/testing';

import { MainDashboardComponent } from './main-dashboard.component';
import { HttpTestingController, provideHttpClientTesting } from '@angular/common/http/testing';
import { RouterTestingModule } from "@angular/router/testing";
import { provideHttpClient, withInterceptorsFromDi } from '@angular/common/http';


describe('MainDashboardComponent', () => {
  let component: MainDashboardComponent;
  let fixture: ComponentFixture<MainDashboardComponent>;
  let httpController: HttpTestingController;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [MainDashboardComponent, RouterTestingModule],
      providers: [provideHttpClient(withInterceptorsFromDi()), provideHttpClientTesting()]
    })
      .compileComponents();

    fixture = TestBed.createComponent(MainDashboardComponent);
    component = fixture.componentInstance;
    httpController = TestBed.inject(HttpTestingController);
    fixture.detectChanges();
  });

  it('should create', () => {
    expect(component).toBeTruthy();
  });

  it('should display the environment, track and version returned by the backend', () => {
    httpController.expectOne('/api/deployment-info').flush({
      environment: 'production',
      track: 'canary',
      version: 'v1.4.0'
    });
    fixture.detectChanges();

    const banner = fixture.nativeElement.querySelector('output');
    expect(banner.textContent).toContain('DÉPLOIEMENT');
    expect(banner.textContent).toContain('PRODUCTION');
    expect(banner.textContent).toContain('CANARY');
    expect(banner.textContent).toContain('v1.4.0');
    expect(banner.classList).toContain('is-info');
  });

  it('should use the staging banner style outside production', () => {
    component.deployment = {
      environment: 'staging',
      track: 'stable',
      version: 'v1.4.0-rc.1'
    };
    fixture.detectChanges();

    const banner = fixture.nativeElement.querySelector('output');
    expect(banner.textContent).toContain('STAGING');
    expect(banner.textContent).toContain('v1.4.0-rc.1');
    expect(banner.classList).toContain('is-warning');
  });
});
